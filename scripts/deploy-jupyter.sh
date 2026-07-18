#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
require_command helm
require_command kubectl
: "${KUBECONFIG:?Set KUBECONFIG to the isolated lab kubeconfig first.}"

helm repo add jupyterhub https://hub.jupyter.org/helm-chart/ --force-update
helm repo update
kubectl create namespace jupyter --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install jupyterhub jupyterhub/jupyterhub \
  --version 4.4.0 \
  --namespace jupyter \
  --values "${REPO_ROOT}/platform/jupyter/values.lab.yaml" \
  --wait --timeout 15m
