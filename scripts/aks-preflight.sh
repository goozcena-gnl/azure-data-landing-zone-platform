#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)

LOCATION=""
VM_SIZE=""
NODE_COUNT=""
ENABLE_AKS=""
ENABLE_JUPYTER=""
TFVARS_FILE=""
JSON_OUTPUT=""
CHECK_CI=false
declare -a ADMIN_GROUP_IDS=()
declare -a BLOCKERS=()
declare -a WARNINGS=()
declare -a PASSES=()

usage() {
  cat <<'EOF'
Usage: scripts/aks-preflight.sh [options]

Read-only AKS readiness inspection. It never registers providers, creates
groups, changes quota, selects a fallback region/SKU, or deploys resources.

Options:
  --location REGION          Azure region (default: TF_VAR_location/tfvars/francecentral)
  --vm-size SKU              AKS system-node SKU (default: TF_VAR_aks_node_vm_size/tfvars)
  --node-count N             System-node count, 1-3
  --enable-aks BOOL          Terraform AKS intent, true or false
  --enable-jupyter BOOL      Post-AKS Jupyter intent, true or false
  --admin-group-id UUID      Entra security-group object ID; repeatable
  --tfvars PATH              Optional local tfvars file to inspect
  --check-ci                 Require the environment used by the GitHub OIDC workflow
  --json-output PATH|-       Write a redacted machine-readable summary
  --help                     Show help

Precedence: command line > TF_VAR_* environment > --tfvars > safe defaults.
Identifiers are used for read-only checks but omitted from the summary.
EOF
}

pass() {
  PASSES+=("$1")
  printf 'PASS    %s\n' "$1"
}

warn() {
  WARNINGS+=("$1")
  printf 'WARN    %s\n' "$1" >&2
}

block() {
  BLOCKERS+=("$1")
  printf 'BLOCKED %s\n' "$1" >&2
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'ERROR: required command not found: %s\n' "$1" >&2
    exit 2
  }
}

is_uuid() {
  [[ "$1" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
}

normalize_bool() {
  case "${1,,}" in
    true|1|yes) printf 'true\n' ;;
    false|0|no) printf 'false\n' ;;
    *) return 1 ;;
  esac
}

tfvar_raw() {
  local key=$1
  [[ -n "$TFVARS_FILE" && -f "$TFVARS_FILE" ]] || return 1
  awk -v key="$key" '
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      sub(/#.*/, "")
      sub(/^[^=]*=[[:space:]]*/, "")
      sub(/[[:space:]]+$/, "")
      print
      exit
    }
  ' "$TFVARS_FILE"
}

tfvar_scalar() {
  local raw
  raw=$(tfvar_raw "$1") || return 1
  [[ -n "$raw" ]] || return 1
  if [[ "$raw" == \"*\" ]]; then
    raw=${raw#\"}
    raw=${raw%\"}
  fi
  printf '%s\n' "$raw"
}

while (($#)); do
  case "$1" in
    --location) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; LOCATION=$2; shift 2 ;;
    --vm-size) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; VM_SIZE=$2; shift 2 ;;
    --node-count) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; NODE_COUNT=$2; shift 2 ;;
    --enable-aks) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; ENABLE_AKS=$2; shift 2 ;;
    --enable-jupyter) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; ENABLE_JUPYTER=$2; shift 2 ;;
    --admin-group-id) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; ADMIN_GROUP_IDS+=("$2"); shift 2 ;;
    --tfvars) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; TFVARS_FILE=$2; shift 2 ;;
    --check-ci) CHECK_CI=true; shift ;;
    --json-output) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; JSON_OUTPUT=$2; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

require_command az
require_command jq
require_command awk

if [[ -z "$TFVARS_FILE" && -f "$REPO_ROOT/infra/landing-zone/terraform.tfvars" ]]; then
  TFVARS_FILE="$REPO_ROOT/infra/landing-zone/terraform.tfvars"
fi
if [[ -n "$TFVARS_FILE" && ! -f "$TFVARS_FILE" ]]; then
  printf 'ERROR: tfvars file not found: %s\n' "$TFVARS_FILE" >&2
  exit 2
fi

LOCATION=${LOCATION:-${TF_VAR_location:-$(tfvar_scalar location 2>/dev/null || printf 'francecentral')}}
VM_SIZE=${VM_SIZE:-${TF_VAR_aks_node_vm_size:-$(tfvar_scalar aks_node_vm_size 2>/dev/null || printf 'Standard_D2s_v5')}}
NODE_COUNT=${NODE_COUNT:-${TF_VAR_aks_node_count:-$(tfvar_scalar aks_node_count 2>/dev/null || printf '1')}}
ENABLE_AKS=${ENABLE_AKS:-${TF_VAR_enable_aks:-$(tfvar_scalar enable_aks 2>/dev/null || printf 'false')}}
ENABLE_JUPYTER=${ENABLE_JUPYTER:-${TF_VAR_enable_jupyter:-$(tfvar_scalar enable_jupyter 2>/dev/null || printf 'false')}}

if ! ENABLE_AKS=$(normalize_bool "$ENABLE_AKS"); then
  block "enable_aks must be true or false."
  ENABLE_AKS=false
fi
if ! ENABLE_JUPYTER=$(normalize_bool "$ENABLE_JUPYTER"); then
  block "enable_jupyter must be true or false."
  ENABLE_JUPYTER=false
fi
if [[ -z "$LOCATION" || ! "$LOCATION" =~ ^[a-z0-9]+$ ]]; then
  block "Set a non-empty canonical Azure region with --location or TF_VAR_location."
fi
if [[ -z "$VM_SIZE" || ! "$VM_SIZE" =~ ^Standard_[A-Za-z0-9_]+$ ]]; then
  block "Set a non-empty Standard Azure VM SKU with --vm-size or TF_VAR_aks_node_vm_size."
fi
if [[ ! "$NODE_COUNT" =~ ^[0-9]+$ ]] || ((10#$NODE_COUNT < 1 || 10#$NODE_COUNT > 3)); then
  block "System-node count must be an integer from 1 through 3."
fi
if [[ "$ENABLE_JUPYTER" == true && "$ENABLE_AKS" != true ]]; then
  block "Jupyter cannot be enabled while AKS is disabled."
fi

if ((${#ADMIN_GROUP_IDS[@]} == 0)); then
  admin_json=${TF_VAR_aks_admin_group_object_ids:-$(tfvar_raw aks_admin_group_object_ids 2>/dev/null || printf '[]')}
  if jq -e 'type == "array" and all(.[]; type == "string")' >/dev/null 2>&1 <<< "$admin_json"; then
    mapfile -t ADMIN_GROUP_IDS < <(jq -r '.[]' <<< "$admin_json")
  else
    block "AKS admin groups must be supplied as a JSON-compatible string list or repeated --admin-group-id values."
  fi
fi
if [[ "$ENABLE_AKS" == true && ${#ADMIN_GROUP_IDS[@]} -eq 0 ]]; then
  block "AKS is enabled but no Entra administrator security-group object ID is configured."
fi

printf 'Configuration: region=%s, SKU=%s, nodes=%s, AKS=%s, Jupyter=%s\n' \
  "$LOCATION" "$VM_SIZE" "$NODE_COUNT" "$ENABLE_AKS" "$ENABLE_JUPYTER"

account_json=""
if ! account_json=$(az account show --output json --only-show-errors 2>/dev/null); then
  block "Azure CLI is not authenticated. Run az login and select the intended subscription."
elif ! jq -e 'type == "object" and (.id | type) == "string" and (.tenantId | type) == "string" and (.name | type) == "string"' \
  >/dev/null 2>&1 <<< "$account_json"; then
  block "Azure CLI returned an incomplete active-subscription record."
else
  subscription_name=$(jq -r '.name' <<< "$account_json")
  pass "Active Azure subscription detected: ${subscription_name} (subscription and tenant IDs redacted)."
fi

if [[ -n "$account_json" ]]; then
  locations_json=""
  if ! locations_json=$(az account list-locations --output json --only-show-errors 2>/dev/null); then
    block "Unable to list Azure regions for the active subscription."
  elif jq -e --arg location "$LOCATION" 'any(.[]; .name == $location)' >/dev/null 2>&1 <<< "$locations_json"; then
    pass "Selected region is recognized by the active subscription."
  else
    block "Selected region '$LOCATION' was not returned for the active subscription."
  fi

  required_providers=(
    Microsoft.Authorization
    Microsoft.Compute
    Microsoft.ContainerService
    Microsoft.ManagedIdentity
    Microsoft.Network
    Microsoft.OperationalInsights
  )
  for provider in "${required_providers[@]}"; do
    state=""
    if ! state=$(az provider show --namespace "$provider" --query registrationState --output tsv --only-show-errors 2>/dev/null); then
      block "Unable to read registration state for $provider."
    elif [[ "$state" == Registered ]]; then
      pass "Resource provider $provider is registered."
    else
      block "Resource provider $provider is '$state'; an authorized operator must register it."
    fi
  done

  versions_json=""
  if ! versions_json=$(az aks get-versions --location "$LOCATION" --output json --only-show-errors 2>/dev/null); then
    block "Unable to list AKS Kubernetes versions in '$LOCATION'."
  else
    version_count=$(jq '[.. | objects | (.orchestratorVersion? // .version? // empty) | select(type == "string")] | unique | length' <<< "$versions_json" 2>/dev/null || printf '0')
    if [[ "$version_count" =~ ^[0-9]+$ ]] && ((version_count > 0)); then
      pass "AKS reports $version_count supported Kubernetes version record(s) in the selected region."
    else
      block "AKS returned no parseable Kubernetes versions in '$LOCATION'."
    fi
  fi

  sku_json=""
  selected_sku=""
  if ! sku_json=$(az vm list-skus --location "$LOCATION" --resource-type virtualMachines \
    --size "$VM_SIZE" --all --output json --only-show-errors 2>/dev/null); then
    block "Unable to query VM SKU availability for '$VM_SIZE' in '$LOCATION'."
  else
    selected_sku=$(jq -ce --arg sku "$VM_SIZE" '[.[] | select(.name == $sku)] | first // empty' <<< "$sku_json" 2>/dev/null || true)
    if [[ -z "$selected_sku" ]]; then
      block "Selected VM SKU '$VM_SIZE' is not listed in '$LOCATION'. No fallback was selected."
    else
      restriction_count=$(jq '(.restrictions // []) | length' <<< "$selected_sku")
      if ((restriction_count > 0)); then
        reasons=$(jq -r '[.restrictions[]? | (.reasonCode // .type // "restriction")] | unique | join(", ")' <<< "$selected_sku")
        block "Selected VM SKU '$VM_SIZE' is restricted in '$LOCATION' ($reasons). Choose explicitly after review."
      else
        pass "Selected VM SKU '$VM_SIZE' is listed without subscription restrictions in '$LOCATION'."
      fi
    fi
  fi

  if [[ -n "$selected_sku" ]]; then
    family=$(jq -r '.family // empty' <<< "$selected_sku")
    vcpus=$(jq -r '[.capabilities[]? | select(.name == "vCPUs") | .value] | first // empty' <<< "$selected_sku")
    if [[ -z "$family" || ! "$vcpus" =~ ^[0-9]+$ ]]; then
      block "Unable to determine the VM-family quota requirement for '$VM_SIZE'."
    else
      required_vcpus=$((10#$vcpus * 10#$NODE_COUNT))
      usage_json=""
      if ! usage_json=$(az vm list-usage --location "$LOCATION" --output json --only-show-errors 2>/dev/null); then
        block "Unable to query regional VM-family quota in '$LOCATION'."
      else
        quota=$(jq -ce --arg family "$family" \
          '[.[] | select(((.name.value // "") | ascii_downcase) == ($family | ascii_downcase))] | first // empty' \
          <<< "$usage_json" 2>/dev/null || true)
        if [[ -z "$quota" ]]; then
          block "No quota record matched VM family '$family'; verify quota in Azure Portal."
        else
          current=$(jq -r '.currentValue' <<< "$quota")
          limit=$(jq -r '.limit' <<< "$quota")
          if [[ "$current" =~ ^[0-9]+$ && "$limit" =~ ^[0-9]+$ ]] && ((current + required_vcpus <= limit)); then
            pass "Regional VM-family quota can cover $required_vcpus requested vCPU(s) at current usage."
          else
            block "Regional VM-family quota cannot prove capacity for $required_vcpus requested vCPU(s); review or increase quota."
          fi
        fi
      fi
    fi
  fi

  for group_id in "${ADMIN_GROUP_IDS[@]}"; do
    if ! is_uuid "$group_id"; then
      block "An AKS administrator-group value is not a valid UUID."
      continue
    fi
    group_json=""
    if ! group_json=$(az ad group show --group "$group_id" --output json --only-show-errors 2>/dev/null); then
      block "An AKS administrator group could not be read; verify the object ID and Microsoft Graph permissions."
    elif [[ "$(jq -r '.securityEnabled // false' <<< "$group_json")" == true ]]; then
      pass "An explicitly configured AKS administrator group exists and is security-enabled (object ID redacted)."
    else
      block "A configured AKS administrator group is not security-enabled."
    fi
  done
fi

if [[ "$CHECK_CI" == true ]]; then
  ci_variables=(
    AZURE_CLIENT_ID
    AZURE_TENANT_ID
    AZURE_SUBSCRIPTION_ID
    TF_STATE_RESOURCE_GROUP
    TF_STATE_STORAGE_ACCOUNT
    TF_STATE_CONTAINER
    TF_STATE_KEY
  )
  missing_ci=()
  for variable in "${ci_variables[@]}"; do
    [[ -n "${!variable:-}" ]] || missing_ci+=("$variable")
  done
  if ((${#missing_ci[@]} > 0)); then
    block "CI/OIDC mode is missing required variables: $(IFS=,; printf '%s' "${missing_ci[*]}")."
  else
    pass "Required GitHub OIDC/backend environment variables are present (values redacted)."
  fi
fi

if [[ -n "$JSON_OUTPUT" ]]; then
  blockers_json=$(printf '%s\n' "${BLOCKERS[@]:-}" | jq -Rsc 'split("\n") | map(select(length > 0))')
  warnings_json=$(printf '%s\n' "${WARNINGS[@]:-}" | jq -Rsc 'split("\n") | map(select(length > 0))')
  passes_json=$(printf '%s\n' "${PASSES[@]:-}" | jq -Rsc 'split("\n") | map(select(length > 0))')
  summary=$(jq -n \
    --arg location "$LOCATION" --arg vm_size "$VM_SIZE" --argjson node_count "${NODE_COUNT:-0}" \
    --argjson enable_aks "$ENABLE_AKS" --argjson enable_jupyter "$ENABLE_JUPYTER" \
    --argjson blockers "$blockers_json" --argjson warnings "$warnings_json" --argjson passes "$passes_json" \
    '{
      schema_version: 1,
      configuration: {
        location: $location,
        aks_node_vm_size: $vm_size,
        aks_node_count: $node_count,
        enable_aks: $enable_aks,
        enable_jupyter: $enable_jupyter
      },
      identifiers_redacted: true,
      passes: $passes,
      warnings: $warnings,
      blockers: $blockers,
      ready: ($blockers | length == 0)
    }')
  if [[ "$JSON_OUTPUT" == - ]]; then
    printf '%s\n' "$summary"
  else
    printf '%s\n' "$summary" > "$JSON_OUTPUT"
    chmod 0600 "$JSON_OUTPUT"
  fi
fi

printf '\nAKS preflight summary: %d pass, %d warning, %d blocker\n' \
  "${#PASSES[@]}" "${#WARNINGS[@]}" "${#BLOCKERS[@]}"
((${#BLOCKERS[@]} == 0))
