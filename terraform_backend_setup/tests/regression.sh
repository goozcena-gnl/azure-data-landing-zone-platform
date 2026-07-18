#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=terraform_backend_setup/terraform_setup.sh
source "$SCRIPT_DIR/../terraform_setup.sh"
trap - ERR

PASSED=0
FAILED=0

pass() {
  PASSED=$((PASSED + 1))
  printf 'PASS: %s\n' "$1"
}

fail() {
  FAILED=$((FAILED + 1))
  printf 'FAIL: %s\n' "$1" >&2
}

assert_equal() {
  local name=$1 expected=$2 actual=$3
  if [[ "$expected" == "$actual" ]]; then
    pass "$name"
  else
    fail "$name (expected '$expected', got '$actual')"
  fi
}

assert_contains() {
  local name=$1 haystack=$2 needle=$3
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$name"
  else
    fail "$name (missing '$needle')"
  fi
}

assert_success() {
  local name=$1
  shift
  if "$@" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name"
  fi
}

assert_failure() {
  local name=$1
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$name (unexpected success)"
  else
    pass "$name"
  fi
}

readonly PRINCIPAL_FIXTURE="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
readonly TARGET_SCOPE="/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-lab/providers/Microsoft.Storage/storageAccounts/stlab"
readonly ROLE="$STORAGE_BLOB_DATA_CONTRIBUTOR"

assert_equal "scoped role lookup: zero assignments" "0" \
  "$(count_effective_role_assignments_json '[]' "$ROLE" "$TARGET_SCOPE")"

direct_json=$(jq -cn \
  --arg role "$ROLE" --arg principal "$PRINCIPAL_FIXTURE" --arg scope "$TARGET_SCOPE" \
  '[{roleDefinitionName:$role,principalId:$principal,scope:$scope}]')
assert_equal "scoped role lookup: one direct assignment" "1" \
  "$(count_effective_role_assignments_json "$direct_json" "$ROLE" "$TARGET_SCOPE")"

unrelated_json=$(jq -cn \
  --arg principal "$PRINCIPAL_FIXTURE" --arg target "$TARGET_SCOPE" \
  '[
    {roleDefinitionName:"Reader",principalId:$principal,scope:$target},
    {roleDefinitionName:"Storage Blob Data Contributor",principalId:$principal,scope:($target + "/blobServices/default")},
    {roleDefinitionName:"Storage Blob Data Contributor",principalId:"",scope:$target}
  ]')
assert_equal "scoped role lookup: unrelated assignments ignored" "0" \
  "$(count_effective_role_assignments_json "$unrelated_json" "$ROLE" "$TARGET_SCOPE")"

inherited_json=$(jq -cn \
  --arg role "$ROLE" --arg principal "$PRINCIPAL_FIXTURE" --arg target "$TARGET_SCOPE" \
  '[
    {roleDefinitionName:$role,principalId:$principal,scope:"/subscriptions/00000000-0000-0000-0000-000000000000"},
    {roleDefinitionName:$role,principalId:$principal,scope:$target}
  ]')
assert_equal "scoped role lookup: inherited and direct assignments retained" "2" \
  "$(count_effective_role_assignments_json "$inherited_json" "$ROLE" "$TARGET_SCOPE")"

role_function=$(declare -f role_assignment_count)
assert_contains "scoped role lookup: explicit object-ID filter" "$role_function" '--assignee-object-id'
assert_contains "scoped role lookup: explicit scope filter" "$role_function" '--scope'
if [[ "$role_function" == *'--all'* ]]; then
  fail "scoped role lookup: incompatible --all flag absent"
else
  pass "scoped role lookup: incompatible --all flag absent"
fi

secure_storage_json='{
  "location": "francecentral",
  "kind": "StorageV2",
  "sku": {
    "name": "Standard_LRS"
  },
  "enableHttpsTrafficOnly": true,
  "minimumTlsVersion": "TLS1_2",
  "allowBlobPublicAccess": false,
  "allowSharedKeyAccess": false
}'
normalized=$(normalize_storage_account_json "$secure_storage_json")
assert_equal "storage JSON: multiline location preserved" "francecentral" "$(jq -r '.location' <<< "$normalized")"
assert_equal "storage JSON: false blob-public value preserved" "false" "$(jq -r '.blob_public_access | tostring' <<< "$normalized")"
assert_equal "storage JSON: false shared-key value preserved" "false" "$(jq -r '.shared_key_access | tostring' <<< "$normalized")"

null_storage_json='{
  "location": "francecentral",
  "kind": "StorageV2",
  "sku": {"name": "Standard_LRS"},
  "enableHttpsTrafficOnly": null,
  "minimumTlsVersion": null,
  "allowBlobPublicAccess": null,
  "allowSharedKeyAccess": null
}'
normalized_null=$(normalize_storage_account_json "$null_storage_json")
assert_equal "storage JSON: null differs from false" "null" "$(jq -r '.shared_key_access | tostring' <<< "$normalized_null")"

missing_storage_json='{
  "location": "francecentral",
  "kind": "StorageV2",
  "sku": {"name": "Standard_LRS"},
  "enableHttpsTrafficOnly": true,
  "minimumTlsVersion": "TLS1_2",
  "allowBlobPublicAccess": false
}'
assert_failure "storage JSON: missing property fails closed" normalize_storage_account_json "$missing_storage_json"

empty_storage_json='{
  "location": "francecentral",
  "kind": "StorageV2",
  "sku": {"name": "Standard_LRS"},
  "enableHttpsTrafficOnly": true,
  "minimumTlsVersion": "",
  "allowBlobPublicAccess": false,
  "allowSharedKeyAccess": false
}'
assert_failure "storage JSON: empty property fails closed" normalize_storage_account_json "$empty_storage_json"

# shellcheck disable=SC2329 # Mock invoked indirectly by the function under test.
az() { return 42; }
STORAGE_ACCOUNT=stlab
RESOURCE_GROUP=rg-lab
SUBSCRIPTION_ID=00000000-0000-0000-0000-000000000000
assert_failure "storage JSON: Azure CLI error is not treated as data" storage_account_properties_json
unset -f az

LOCATION=francecentral
SKU=Standard_LRS
FORCE=true
DISABLE_SHARED_KEY=true
MUTATION_COUNT=0
MUTATION_ARGS=""
STORAGE_RESOURCE_ID=""
storage_account_properties_json() { normalize_storage_account_json "$secure_storage_json"; }
az() {
  local argument saw_query=false
  for argument in "$@"; do
    if [[ "$argument" == --query ]]; then saw_query=true; continue; fi
    if [[ "$saw_query" == true && "$argument" == id ]]; then
      printf '%s\n' "$TARGET_SCOPE"
      return 0
    fi
  done
  return 43
}
run_mutation() {
  local argument
  MUTATION_COUNT=$((MUTATION_COUNT + 1))
  MUTATION_ARGS=""
  for argument in "$@"; do
    MUTATION_ARGS+="${MUTATION_ARGS:+ }${argument}"
  done
}
merge_tags() { :; }
reconcile_existing_storage >/dev/null 2>&1
reconcile_existing_storage >/dev/null 2>&1
assert_equal "existing secure storage: repeated reconciliation is idempotent" "0" "$MUTATION_COUNT"

hardening_storage_json='{
  "location": "francecentral",
  "kind": "StorageV2",
  "sku": {"name": "Standard_LRS"},
  "enableHttpsTrafficOnly": false,
  "minimumTlsVersion": null,
  "allowBlobPublicAccess": true,
  "allowSharedKeyAccess": true
}'
storage_account_properties_json() { normalize_storage_account_json "$hardening_storage_json"; }
MUTATION_COUNT=0
MUTATION_ARGS=""
reconcile_existing_storage >/dev/null 2>&1
assert_equal "existing insecure storage: one hardening mutation" "1" "$MUTATION_COUNT"
assert_contains "existing insecure storage: HTTPS hardened" "$MUTATION_ARGS" "--https-only true"
assert_contains "existing insecure storage: TLS hardened" "$MUTATION_ARGS" "--min-tls-version TLS1_2"
assert_contains "existing insecure storage: blob public access disabled" "$MUTATION_ARGS" "--allow-blob-public-access false"
assert_contains "existing insecure storage: shared-key access disabled" "$MUTATION_ARGS" "--allow-shared-key-access false"

blob_json='{
  "isVersioningEnabled": true,
  "deleteRetentionPolicy": {
    "enabled": true,
    "days": 14
  },
  "containerDeleteRetentionPolicy": {
    "enabled": true,
    "days": 14
  }
}'
normalized_blob=$(normalize_blob_service_json "$blob_json")
assert_equal "blob JSON: versioning parsed from multiline JSON" "true" "$(jq -r '.versioning | tostring' <<< "$normalized_blob")"
assert_equal "blob JSON: retention days parsed" "14" "$(jq -r '.blob_delete_days | tostring' <<< "$normalized_blob")"

network_json='{
  "publicNetworkAccess": "Enabled",
  "networkRuleSet": {
    "defaultAction": "Deny"
  }
}'
normalized_network=$(normalize_network_json "$network_json")
assert_equal "network JSON: default action parsed" "Deny" "$(jq -r '.default_action' <<< "$normalized_network")"

invalid_json='{not-json'
assert_failure "structured parsing: malformed JSON fails closed" normalize_storage_account_json "$invalid_json"

printf '\nBackend helper regression summary: %d passed, %d failed\n' "$PASSED" "$FAILED"
((FAILED == 0))
