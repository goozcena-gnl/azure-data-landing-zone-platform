#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
require_command terraform
require_file "${LANDING_ZONE_DIR}/backend.hcl"
require_file "${LANDING_ZONE_DIR}/terraform.tfvars"
prepare_artifacts

terraform -chdir="${LANDING_ZONE_DIR}" init -input=false -backend-config=backend.hcl
terraform -chdir="${LANDING_ZONE_DIR}" validate -no-color
terraform -chdir="${LANDING_ZONE_DIR}" plan -input=false -lock-timeout=5m -out="${ARTIFACTS_DIR}/lab.tfplan"
terraform -chdir="${LANDING_ZONE_DIR}" show -no-color "${ARTIFACTS_DIR}/lab.tfplan" > "${ARTIFACTS_DIR}/lab-plan.txt"
sha256sum "${ARTIFACTS_DIR}/lab.tfplan" > "${ARTIFACTS_DIR}/lab.tfplan.sha256"
chmod 600 \
  "${ARTIFACTS_DIR}/lab.tfplan" \
  "${ARTIFACTS_DIR}/lab.tfplan.sha256" \
  "${ARTIFACTS_DIR}/lab-plan.txt"
log 'Review artifacts/lab-plan.txt before applying. Treat the binary plan as sensitive.'
