#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
require_command terraform

terraform fmt -check -recursive "${REPO_ROOT}"
for component in "${BOOTSTRAP_DIR}" "${LANDING_ZONE_DIR}"; do
  log "Validating ${component#"${REPO_ROOT}"/}"
  terraform -chdir="$component" init -backend=false -input=false
  terraform -chdir="$component" validate -no-color
done
