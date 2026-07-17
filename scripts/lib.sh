#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC2034
LANDING_ZONE_DIR="${REPO_ROOT}/infra/landing-zone"
# shellcheck disable=SC2034
BOOTSTRAP_DIR="${REPO_ROOT}/infra/bootstrap"
ARTIFACTS_DIR="${REPO_ROOT}/artifacts"

log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
require_command() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }
require_file() { [[ -f "$1" ]] || die "Required file not found: $1"; }

prepare_artifacts() {
  mkdir -p "${ARTIFACTS_DIR}"
  chmod 700 "${ARTIFACTS_DIR}"
}

confirm_destructive_action() {
  local phrase="$1"
  [[ "${CI:-}" == "true" ]] && return 0
  printf 'Type %s to continue: ' "$phrase"
  read -r answer
  [[ "$answer" == "$phrase" ]] || die 'Confirmation phrase did not match.'
}
