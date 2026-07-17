#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
require_command terraform
require_file "${LANDING_ZONE_DIR}/backend.hcl"
require_file "${LANDING_ZONE_DIR}/terraform.tfvars"
prepare_artifacts
confirm_destructive_action DESTROY-LAB

terraform -chdir="${LANDING_ZONE_DIR}" init -input=false -backend-config=backend.hcl
terraform -chdir="${LANDING_ZONE_DIR}" plan -destroy -input=false -lock-timeout=5m -out="${ARTIFACTS_DIR}/destroy.tfplan"
terraform -chdir="${LANDING_ZONE_DIR}" apply -input=false -lock-timeout=5m "${ARTIFACTS_DIR}/destroy.tfplan"
"${REPO_ROOT}/scripts/verify-cleanup.sh"
