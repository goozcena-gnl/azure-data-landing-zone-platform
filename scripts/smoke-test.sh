#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
require_command az
require_command terraform
prepare_artifacts

subscription_id="$(az account show --query id -o tsv)"
[[ -n "$subscription_id" ]] || die 'Azure CLI is not authenticated.'
terraform -chdir="${LANDING_ZONE_DIR}" output -json > "${ARTIFACTS_DIR}/terraform-outputs.json"
az resource list --tag "project=azure-data-landing-zone" --query '[].{name:name,type:type,resourceGroup:resourceGroup}' -o json > "${ARTIFACTS_DIR}/azure-resource-inventory.json"

aks_name="$(terraform -chdir="${LANDING_ZONE_DIR}" output -raw aks_cluster_name 2>/dev/null || true)"
if [[ -n "$aks_name" && "$aks_name" != "null" ]]; then
  "${REPO_ROOT}/scripts/get-aks-credentials.sh" >/dev/null
  export KUBECONFIG="${ARTIFACTS_DIR}/kubeconfig-lab"
  require_command kubectl
  kubectl get nodes -o wide > "${ARTIFACTS_DIR}/aks-nodes.txt"
  kubectl get pods -A -o wide > "${ARTIFACTS_DIR}/aks-pods.txt"
  kubectl wait --for=condition=Ready nodes --all --timeout=10m
  if kubectl get pods -A --no-headers | awk '$4 ~ /CrashLoopBackOff|Error|ImagePullBackOff/ {bad=1} END {exit bad ? 0 : 1}'; then
    die 'Unhealthy Kubernetes workload detected. See artifacts/aks-pods.txt.'
  fi
fi
log 'Smoke-test evidence written under artifacts/. Review and redact before publication.'
