#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

GROUP_ID=""
SEARCH=""
OUTPUT=json
SHOW_OBJECT_IDS=false

usage() {
  cat <<'EOF'
Usage: scripts/entra-aks-admin-group.sh [options]

Read-only discovery and validation of Microsoft Entra security groups for AKS.
The script never creates a group or changes membership.

Options:
  --group-id UUID       Validate one stable group object ID.
  --search TEXT         Search security-enabled groups by display-name text.
  --show-object-ids     Include object IDs in discovery output.
  --output json|table   Output format for discovery (default: json).
  --help                Show help.

Use display names only for discovery. Persist the validated object ID in
aks_admin_group_object_ids; display names are not stable identifiers.
EOF
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

while (($#)); do
  case "$1" in
    --group-id) [[ $# -ge 2 ]] || die "Missing value for --group-id."; GROUP_ID=$2; shift 2 ;;
    --search) [[ $# -ge 2 ]] || die "Missing value for --search."; SEARCH=$2; shift 2 ;;
    --show-object-ids) SHOW_OBJECT_IDS=true; shift ;;
    --output) [[ $# -ge 2 ]] || die "Missing value for --output."; OUTPUT=$2; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

command -v az >/dev/null 2>&1 || die "Azure CLI is required."
command -v jq >/dev/null 2>&1 || die "jq is required."
[[ "$OUTPUT" == json || "$OUTPUT" == table ]] || die "--output must be json or table."
[[ -z "$GROUP_ID" || -z "$SEARCH" ]] || die "Use --group-id or --search, not both."

if ! az account show --output none --only-show-errors 2>/dev/null; then
  die "Azure CLI is not authenticated."
fi

if [[ -n "$GROUP_ID" ]]; then
  [[ "$GROUP_ID" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] ||
    die "--group-id must be a UUID."
  if ! group_json=$(az ad group show --group "$GROUP_ID" --output json --only-show-errors 2>/dev/null); then
    die "The supplied group object ID was not readable. Verify the ID and Microsoft Graph permissions."
  fi
  if [[ "$(jq -r '.securityEnabled // false' <<< "$group_json")" != true ]]; then
    die "The supplied group exists but is not security-enabled."
  fi
  jq '{
    object_id: .id,
    display_name: .displayName,
    security_enabled: .securityEnabled,
    mail_enabled: .mailEnabled,
    membership_type: (.groupTypes // [])
  }' <<< "$group_json"
  printf 'Validated by stable object ID; no Entra changes were made.\n' >&2
  exit 0
fi

filter='securityEnabled eq true'
if [[ -n "$SEARCH" ]]; then
  [[ "$SEARCH" != *$'\n'* && "$SEARCH" != *$'\r'* ]] || die "Search text cannot contain a newline."
  escaped_search=${SEARCH//\'/\'\'}
  filter+=" and startswith(displayName,'${escaped_search}')"
fi

if ! groups_json=$(az ad group list --filter "$filter" --output json --only-show-errors 2>/dev/null); then
  die "Unable to list security-enabled groups. Directory Readers or equivalent Microsoft Graph access may be required."
fi

if [[ "$SHOW_OBJECT_IDS" == true ]]; then
  projection='[.[] | {
    object_id: .id,
    display_name: .displayName,
    security_enabled: .securityEnabled,
    mail_enabled: .mailEnabled
  }]'
else
  projection='[.[] | {
    display_name: .displayName,
    security_enabled: .securityEnabled,
    mail_enabled: .mailEnabled,
    object_id: "<redacted; rerun with --show-object-ids>"
  }]'
fi

if [[ "$OUTPUT" == table ]]; then
  jq -r "$projection | ([\"DISPLAY NAME\",\"SECURITY\",\"MAIL\",\"OBJECT ID\"] | @tsv), (.[] | [.display_name,.security_enabled,.mail_enabled,.object_id] | @tsv)" \
    <<< "$groups_json"
else
  jq "$projection" <<< "$groups_json"
fi

printf 'Read-only discovery completed. Validate the selected group with --group-id before configuring Terraform.\n' >&2
