#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
cd "${REPO_ROOT}"
prepare_artifacts

require_command python3
python3 scripts/secret-scan.py --root . --output "${ARTIFACTS_DIR}/secret-scan.json"

if command -v checkov >/dev/null 2>&1; then
  # Some sandbox and desktop shells export proxy values without a URL scheme,
  # which causes Checkov's optional policy-metadata lookup to fail before scan.
  for proxy_var in http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY; do
    proxy_value="${!proxy_var:-}"
    if [[ "${proxy_value}" != http://* && "${proxy_value}" != https://* ]]; then
      unset "${proxy_var}"
    fi
  done
  checkov --directory . --config-file .checkov.yml --output cli --skip-download
else
  die 'checkov is required. Install checkov==3.3.8 in an isolated environment.'
fi
