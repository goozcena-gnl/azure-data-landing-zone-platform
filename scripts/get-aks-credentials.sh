#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
require_command az
require_command terraform
require_command kubelogin
prepare_artifacts

rg="$(terraform -chdir="${LANDING_ZONE_DIR}" output -raw aks_resource_group_name)"
cluster="$(terraform -chdir="${LANDING_ZONE_DIR}" output -raw aks_cluster_name)"
[[ -n "$rg" && "$rg" != "null" && -n "$cluster" && "$cluster" != "null" ]] || die 'AKS outputs are empty.'

export KUBECONFIG="${ARTIFACTS_DIR}/kubeconfig-lab"
az aks get-credentials --resource-group "$rg" --name "$cluster" --file "$KUBECONFIG" --overwrite-existing
chmod 600 "$KUBECONFIG"
printf 'KUBECONFIG=%s\n' "$KUBECONFIG"
