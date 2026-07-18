#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
require_command terraform

terraform_data_root="${TF_DATA_ROOT:-${XDG_CACHE_HOME:-${HOME}/.cache}/azure-data-landing-zone-platform/terraform}"
mkdir -p "$terraform_data_root"

terraform fmt -check -recursive "${REPO_ROOT}"
for component in "${BOOTSTRAP_DIR}" "${LANDING_ZONE_DIR}"; do
  log "Validating ${component#"${REPO_ROOT}"/}"
  component_data_dir="${terraform_data_root}/${component##*/}"
  TF_DATA_DIR="$component_data_dir" terraform -chdir="$component" init -backend=false -input=false
  TF_DATA_DIR="$component_data_dir" terraform -chdir="$component" validate -no-color
done
