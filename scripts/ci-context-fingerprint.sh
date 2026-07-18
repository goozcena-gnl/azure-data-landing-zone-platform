#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

required_variables=(
  ARM_CLIENT_ID
  ARM_TENANT_ID
  ARM_SUBSCRIPTION_ID
  TF_STATE_RESOURCE_GROUP
  TF_STATE_STORAGE_ACCOUNT
  TF_STATE_CONTAINER
  TF_STATE_KEY
  TF_VAR_subscription_id
  TF_VAR_tenant_id
  TF_VAR_name_prefix
  TF_VAR_location
  TF_VAR_owner_tag
  TF_VAR_enable_aks
  TF_VAR_enable_jupyter
  TF_VAR_aks_node_vm_size
  TF_VAR_aks_node_count
  TF_VAR_aks_authorized_ip_ranges
  TF_VAR_aks_admin_group_object_ids
)

command -v sha256sum >/dev/null 2>&1 || {
  printf 'ERROR: sha256sum is required.\n' >&2
  exit 1
}

for variable in "${required_variables[@]}"; do
  if [[ -z "${!variable:-}" ]]; then
    printf 'ERROR: required CI context variable is missing: %s\n' "$variable" >&2
    exit 1
  fi
done

for variable in "${required_variables[@]}"; do
  printf '%s\0%s\0' "$variable" "${!variable}"
done | sha256sum | awk '{print $1}'
