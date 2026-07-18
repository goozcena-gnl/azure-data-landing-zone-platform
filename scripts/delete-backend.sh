#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-${ARM_SUBSCRIPTION_ID:-}}"
RESOURCE_GROUP="${TF_STATE_RESOURCE_GROUP:-}"
STORAGE_ACCOUNT="${TF_STATE_STORAGE_ACCOUNT:-}"
CONTAINER_NAME="${TF_STATE_CONTAINER:-}"
STATE_KEY="${TF_STATE_KEY:-}"
TERRAFORM_DIR="infra/landing-zone"

usage() {
  cat <<'EOF'
Usage: scripts/delete-backend.sh [options]

Delete a dedicated Terraform backend resource group only after the landing-zone
state is empty. This script is intentionally destructive and interactive.

Required options or equivalent environment variables:
  --subscription-id UUID     AZURE_SUBSCRIPTION_ID or ARM_SUBSCRIPTION_ID
  --resource-group NAME      TF_STATE_RESOURCE_GROUP
  --storage-account NAME     TF_STATE_STORAGE_ACCOUNT
  --container NAME           TF_STATE_CONTAINER
  --state-key NAME           TF_STATE_KEY

Optional:
  --terraform-dir PATH       Initialized landing-zone root (default: infra/landing-zone)
  --help                     Show help

Safety gates:
  * active subscription must match;
  * Terraform state must contain zero managed resources;
  * resource group must carry purpose=terraform-state;
  * the resource group must contain only the named storage account;
  * the storage account must contain only the named container;
  * that container must contain only the named state blob;
  * the operator must type DELETE-BACKEND:<resource-group>.

The script uses Microsoft Entra data-plane authentication and never reads a
storage account key.
EOF
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --subscription-id) [[ $# -ge 2 ]] || die "Missing value for --subscription-id."; SUBSCRIPTION_ID=$2; shift 2 ;;
    --resource-group) [[ $# -ge 2 ]] || die "Missing value for --resource-group."; RESOURCE_GROUP=$2; shift 2 ;;
    --storage-account) [[ $# -ge 2 ]] || die "Missing value for --storage-account."; STORAGE_ACCOUNT=$2; shift 2 ;;
    --container) [[ $# -ge 2 ]] || die "Missing value for --container."; CONTAINER_NAME=$2; shift 2 ;;
    --state-key) [[ $# -ge 2 ]] || die "Missing value for --state-key."; STATE_KEY=$2; shift 2 ;;
    --terraform-dir) [[ $# -ge 2 ]] || die "Missing value for --terraform-dir."; TERRAFORM_DIR=$2; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

for command in az terraform jq; do
  command -v "$command" >/dev/null 2>&1 || die "Required command not found: $command"
done

[[ "$SUBSCRIPTION_ID" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] ||
  die "A valid subscription UUID is required."
[[ "$RESOURCE_GROUP" =~ ^[A-Za-z0-9_.()-]{1,90}$ && "$RESOURCE_GROUP" != *. ]] ||
  die "Invalid backend resource-group name."
[[ "$STORAGE_ACCOUNT" =~ ^[a-z0-9]{3,24}$ ]] || die "Invalid storage-account name."
[[ "$CONTAINER_NAME" =~ ^[a-z0-9]([a-z0-9-]{1,61}[a-z0-9])?$ ]] || die "Invalid container name."
[[ -n "$STATE_KEY" && "$STATE_KEY" != *$'\n'* && "$STATE_KEY" != *$'\r'* ]] || die "Invalid state key."
[[ -d "$TERRAFORM_DIR" ]] || die "Terraform directory not found: $TERRAFORM_DIR"

account_json=""
if ! account_json=$(az account show --output json --only-show-errors 2>/dev/null); then
  die "Azure CLI is not authenticated."
fi
active_subscription=$(jq -r '.id // empty' <<< "$account_json")
[[ "${active_subscription,,}" == "${SUBSCRIPTION_ID,,}" ]] ||
  die "The active Azure subscription does not match the explicitly supplied subscription."
printf 'PASS: active subscription matches (identifier redacted).\n'

state_resources=""
if ! state_resources=$(terraform -chdir="$TERRAFORM_DIR" state list 2>/dev/null); then
  die "Unable to read remote Terraform state. Initialize the exact backend first."
fi
if [[ -n "$state_resources" ]]; then
  printf '%s\n' "$state_resources" >&2
  die "Terraform state still contains managed resources; destroy and verify the landing zone first."
fi
printf 'PASS: Terraform state contains zero managed resources.\n'

if ! rg_json=$(az group show --name "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION_ID" \
  --output json --only-show-errors 2>/dev/null); then
  die "The dedicated backend resource group does not exist or is not readable."
fi
purpose=$(jq -r '.tags.purpose // empty' <<< "$rg_json")
[[ "$purpose" == terraform-state ]] ||
  die "Resource group is missing the required purpose=terraform-state safety tag."
printf 'PASS: dedicated backend purpose tag is present.\n'

if ! storage_json=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" \
  --subscription "$SUBSCRIPTION_ID" --output json --only-show-errors 2>/dev/null); then
  die "The named backend storage account does not exist in the dedicated resource group."
fi
storage_id=$(jq -r '.id // empty' <<< "$storage_json")
[[ -n "$storage_id" ]] || die "Backend storage account returned no resource ID."

if ! resources_json=$(az resource list --resource-group "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION_ID" \
  --output json --only-show-errors 2>/dev/null); then
  die "Unable to inventory the dedicated backend resource group."
fi
resource_count=$(jq 'length' <<< "$resources_json")
matching_resource_count=$(jq --arg id "$storage_id" '[.[] | select((.id | ascii_downcase) == ($id | ascii_downcase))] | length' \
  <<< "$resources_json")
[[ "$resource_count" == 1 && "$matching_resource_count" == 1 ]] ||
  die "The backend resource group contains unrelated or unexpected resources; refusing deletion."
printf 'PASS: exact backend scope contains only the named storage account.\n'

if ! containers_json=$(az storage container list --account-name "$STORAGE_ACCOUNT" --auth-mode login \
  --output json --only-show-errors 2>/dev/null); then
  die "Unable to inventory backend containers with Microsoft Entra authorization."
fi
container_count=$(jq 'length' <<< "$containers_json")
matching_container_count=$(jq --arg name "$CONTAINER_NAME" '[.[] | select(.name == $name)] | length' <<< "$containers_json")
[[ "$container_count" == 1 && "$matching_container_count" == 1 ]] ||
  die "The storage account contains unrelated or unexpected containers; refusing deletion."
printf 'PASS: storage account contains only the named backend container.\n'

if ! blobs_json=$(az storage blob list --account-name "$STORAGE_ACCOUNT" --container-name "$CONTAINER_NAME" \
  --auth-mode login --include d --output json --only-show-errors 2>/dev/null); then
  die "Unable to inventory backend blobs with Microsoft Entra authorization."
fi
active_blob_count=$(jq '[.[] | select((.deleted // false) == false)] | length' <<< "$blobs_json")
matching_blob_count=$(jq --arg key "$STATE_KEY" \
  '[.[] | select((.deleted // false) == false and .name == $key)] | length' <<< "$blobs_json")
[[ "$active_blob_count" -le 1 && "$matching_blob_count" == "$active_blob_count" ]] ||
  die "The backend container contains an unrelated active blob; refusing deletion."
printf 'PASS: backend container has no unrelated active blob.\n'

cat <<EOF

DESTRUCTIVE SCOPE
  Subscription ID : <redacted; explicitly matched>
  Resource group  : $RESOURCE_GROUP
  Storage account : $STORAGE_ACCOUNT
  Container       : $CONTAINER_NAME
  State key       : $STATE_KEY

This deletes the entire dedicated resource group. Soft-deleted versions are
removed with the storage account and cannot be recovered through Terraform.
EOF

confirmation="DELETE-BACKEND:${RESOURCE_GROUP}"
printf 'Type %s to continue: ' "$confirmation"
read -r answer
[[ "$answer" == "$confirmation" ]] || die "Confirmation phrase did not match; no deletion was performed."

az group delete --name "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION_ID" \
  --yes --no-wait --only-show-errors
az group wait --name "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION_ID" \
  --deleted --interval 10 --timeout 1200 --only-show-errors

exists=$(az group exists --name "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION_ID" \
  --output tsv --only-show-errors)
[[ "$exists" == false ]] || die "Residual verification failed: resource group still exists."
if az storage account show --name "$STORAGE_ACCOUNT" --subscription "$SUBSCRIPTION_ID" \
  --output none --only-show-errors 2>/dev/null; then
  die "Residual verification failed: storage account is still visible."
fi
printf 'PASS: dedicated backend resource group and storage account are absent.\n'
