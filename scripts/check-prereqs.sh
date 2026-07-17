#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

required=(terraform python3 git)
optional=(az kubectl kubelogin helm tflint checkov shellcheck yamllint markdownlint jq)
for cmd in "${required[@]}"; do require_command "$cmd"; done
for cmd in "${optional[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf 'OK       %s\n' "$cmd"
  else
    printf 'OPTIONAL %s not installed\n' "$cmd"
  fi
done
terraform version
