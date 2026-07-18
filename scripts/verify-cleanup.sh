#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
require_command az

prefix="${TF_VAR_name_prefix:-${TF_VAR_NAME_PREFIX:-}}"
[[ -n "$prefix" ]] || die 'Set TF_VAR_name_prefix to the lab name prefix before cleanup verification.'

remaining_groups="$(az group list --query "[?contains(name, '${prefix}')].name" -o tsv)"
remaining_resources="$(az resource list \
  --tag project=azure-data-landing-zone \
  --query '[].id' \
  -o tsv)"
remaining_policies="$(az policy definition list \
  --query "[?contains(name, '${prefix}')].name" \
  -o tsv)"

failed=false
if [[ -n "$remaining_groups" ]]; then
  printf 'Remaining resource groups containing prefix %s:\n%s\n' \
    "$prefix" "$remaining_groups" >&2
  failed=true
fi
if [[ -n "$remaining_resources" ]]; then
  printf 'Remaining tagged Azure resources:\n%s\n' "$remaining_resources" >&2
  failed=true
fi
if [[ -n "$remaining_policies" ]]; then
  printf 'Remaining custom policy definitions containing prefix %s:\n%s\n' \
    "$prefix" "$remaining_policies" >&2
  failed=true
fi

[[ "$failed" == false ]] || exit 1
log 'No matching resource group, tagged resource, or custom policy definition remains.'
