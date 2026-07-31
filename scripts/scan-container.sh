#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
VERSIONS_FILE="$REPO_ROOT/tools/versions.env"
EXCEPTIONS_FILE="$REPO_ROOT/config/container-vulnerability-exceptions.json"
build_no_cache=false
image_name=""

if [[ "${1:-}" == --build-no-cache ]]; then
  build_no_cache=true
  shift
fi
if (($# > 1)); then
  printf 'Usage: scripts/scan-container.sh [--build-no-cache] [image]\n' >&2
  exit 2
fi
image_name=${1:-"azure-data-landing-zone-platform-dev:scan-$$-${RANDOM}"}

for command in curl docker grep mktemp python3 rm sha256sum tar; do
  command -v "$command" >/dev/null 2>&1 || {
    printf 'ERROR: scan-container requires %s.\n' "$command" >&2
    exit 1
  }
done
docker info >/dev/null 2>&1 || {
  printf 'ERROR: Docker daemon is unavailable.\n' >&2
  exit 1
}

if grep -Ev '^\s*(#.*)?$|^[A-Z][A-Z0-9_]*=[A-Za-z0-9][A-Za-z0-9._:+-]*$' \
  "$VERSIONS_FILE" | grep -q .; then
  printf 'ERROR: unsafe assignment in %s\n' "$VERSIONS_FILE" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$VERSIONS_FILE"

temporary=$(mktemp -d)
remove_image=false
cleanup() {
  rm -rf -- "$temporary"
  if [[ "$remove_image" == true ]]; then
    docker image rm --force "$image_name" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

if [[ "$build_no_cache" == true ]]; then
  remove_image=true
  docker build --no-cache \
    --file "$REPO_ROOT/.devcontainer/Dockerfile" \
    --tag "$image_name" \
    "$REPO_ROOT"
fi
docker image inspect "$image_name" >/dev/null

archive="$temporary/trivy.tar.gz"
curl --proto '=https' --tlsv1.2 --fail --silent --show-error --location \
  --output "$archive" \
  "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz"
printf '%s  %s\n' "$TRIVY_LINUX_AMD64_SHA256" "$archive" | sha256sum --check --status
tar -xzf "$archive" -C "$temporary" trivy

"$temporary/trivy" image --download-db-only
printf 'Pinned scanner and vulnerability-database metadata:\n'
"$temporary/trivy" version --format json
"$temporary/trivy" image \
  --skip-db-update \
  --scanners vuln,secret \
  --severity HIGH,CRITICAL \
  --format json \
  --output "$temporary/scan.json" \
  "$image_name"
python3 "$REPO_ROOT/scripts/container_scan_policy.py" \
  --scan "$temporary/scan.json" \
  --exceptions "$EXCEPTIONS_FILE"
