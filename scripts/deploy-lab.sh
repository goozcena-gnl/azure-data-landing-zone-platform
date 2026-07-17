#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
require_command terraform
require_file "${LANDING_ZONE_DIR}/backend.hcl"
require_file "${LANDING_ZONE_DIR}/terraform.tfvars"
require_file "${ARTIFACTS_DIR}/lab.tfplan"
require_file "${ARTIFACTS_DIR}/lab.tfplan.sha256"

(
  cd "${ARTIFACTS_DIR}"
  sha256sum -c lab.tfplan.sha256
)
terraform -chdir="${LANDING_ZONE_DIR}" init -input=false -backend-config=backend.hcl
confirm_destructive_action APPLY-LAB
terraform -chdir="${LANDING_ZONE_DIR}" apply \
  -input=false \
  -lock-timeout=5m \
  "${ARTIFACTS_DIR}/lab.tfplan"
