#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
if [[ "${DOCTOR_TEST_MODE:-0}" == 1 && -n "${DOCTOR_TEST_REPO_ROOT:-}" ]]; then
  REPO_ROOT=$(readlink -f -- "$DOCTOR_TEST_REPO_ROOT")
fi
VERSIONS_FILE="$REPO_ROOT/tools/versions.env"
CHECK_CONTAINER=false

usage() {
  cat <<'EOF'
Usage: scripts/doctor.sh [--container]

Verify the strict non-deployment validation toolchain. Linux and WSL 2 are
supported. --container additionally verifies that the Docker daemon is usable.
No network, cloud login, or repository mutation is performed.
EOF
}

while (($#)); do
  case "$1" in
    --container) CHECK_CONTAINER=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

if [[ ! -f "$VERSIONS_FILE" ]]; then
  printf 'ERROR: tool version manifest is missing: %s\n' "$VERSIONS_FILE" >&2
  exit 1
fi

if grep -Ev '^\s*(#.*)?$|^[A-Z][A-Z0-9_]*=[A-Za-z0-9][A-Za-z0-9._:+-]*$' \
  "$VERSIONS_FILE" | grep -q .; then
  printf 'ERROR: unsafe or invalid assignment in %s\n' "$VERSIONS_FILE" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$VERSIONS_FILE"

uname_s=${DOCTOR_TEST_UNAME_S:-$(uname -s)}
case "$uname_s" in
  Linux) ;;
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    printf 'ERROR: native Windows shells are unsupported. Use WSL 2 or the Dev Container.\n' >&2
    exit 1
    ;;
  *)
    printf 'ERROR: unsupported operating system: %s\n' "$uname_s" >&2
    exit 1
    ;;
esac

if [[ "${DOCTOR_TEST_MODE:-0}" == 1 ]]; then
  kernel_release=${DOCTOR_TEST_PROC_VERSION:-Linux}
else
  kernel_release=$(cat /proc/sys/kernel/osrelease 2>/dev/null || printf 'Linux')
fi
if [[ "${DOCTOR_TEST_MODE:-0}" != 1 && -f /.dockerenv ]]; then
  platform="Linux container"
elif [[ "$kernel_release" =~ WSL2|wsl2 ]]; then
  platform="WSL 2"
elif [[ "$kernel_release" =~ [Mm]icrosoft|WSL|wsl ]]; then
  printf 'ERROR: WSL 1 is unsupported. Upgrade the distribution to WSL 2 or use the Dev Container.\n' >&2
  exit 1
else
  platform="Linux"
fi

failures=0

pass() { printf 'PASS     %-18s %s\n' "$1" "$2"; }
optional() { printf 'OPTIONAL %-18s %s\n' "$1" "$2"; }
fail() {
  printf 'FAIL     %-18s %s\n' "$1" "$2" >&2
  failures=$((failures + 1))
}

normalize_version() {
  local value=$1
  value=${value#v}
  value=${value#V}
  printf '%s\n' "$value"
}

command_available() {
  local command=$1
  if [[ "${DOCTOR_TEST_MODE:-0}" == 1 &&
        "${DOCTOR_TEST_MISSING_COMMAND:-}" == "$command" ]]; then
    return 1
  fi
  command -v "$command" >/dev/null 2>&1
}

actual_version() {
  case "$1" in
    python3) python3 --version 2>&1 | awk '{print $2}' ;;
    node) node --version 2>&1 | awk 'NR==1 {sub(/^v/,"",$1); print $1}' ;;
    npm) npm --version 2>&1 | awk 'NR==1 {print $1}' ;;
    terraform) terraform version 2>&1 | awk 'NR==1 {sub(/^v/,"",$2); print $2}' ;;
    tflint) tflint --version 2>&1 | awk 'NR==1 {sub(/^v/,"",$3); print $3}' ;;
    checkov) checkov --version 2>&1 | awk 'NR==1 {print $1}' ;;
    yamllint) yamllint --version 2>&1 | awk 'NR==1 {print $2}' ;;
    shellcheck) shellcheck --version 2>&1 | awk '$1=="version:" {print $2}' ;;
    markdownlint) markdownlint --version 2>&1 | awk 'NR==1 {print $1}' ;;
    pre-commit) pre-commit --version 2>&1 | awk 'NR==1 {print $2}' ;;
    helm) helm version --short 2>&1 | awk 'NR==1 {sub(/^v/,"",$1); sub(/\+.*/,"",$1); print $1}' ;;
    kubectl)
      kubectl version --client 2>&1 |
        awk '/Client Version:/ {sub(/^v/,"",$3); print $3; exit} /GitVersion:/ {gsub(/[",]/,"",$2); sub(/^v/,"",$2); print $2; exit}'
      ;;
    kubeconform) kubeconform -v 2>&1 | awk 'NR==1 {sub(/^v/,"",$1); print $1}' ;;
    jq) jq --version 2>&1 | awk 'NR==1 {sub(/^jq-/,"",$1); print $1}' ;;
    bats) bats --version 2>&1 | awk 'NR==1 {print $2}' ;;
    *) return 2 ;;
  esac
}

check_presence() {
  local command=$1
  if command_available "$command"; then
    pass "$command" "available"
  else
    fail "$command" "required executable is missing"
  fi
}

check_version() {
  local command=$1 expected=$2 observed
  if ! command_available "$command"; then
    fail "$command" "required $expected; executable is missing"
    return
  fi
  observed=$(normalize_version "$(actual_version "$command")")
  if [[ "$observed" == "$expected" ]]; then
    pass "$command" "$observed (expected $expected)"
  else
    fail "$command" "${observed:-unknown} (expected $expected)"
  fi
}

check_python_series() {
  local observed
  if ! command_available python3; then
    fail "python3" "required $PYTHON_SERIES.x; executable is missing"
    return
  fi
  observed=$(normalize_version "$(actual_version python3)")
  case "$observed" in
    "$PYTHON_SERIES"|"$PYTHON_SERIES".*)
      pass "python3" "$observed (supported $PYTHON_SERIES.x; tested $PYTHON_TESTED_VERSION)"
      ;;
    *) fail "python3" "${observed:-unknown} (supported $PYTHON_SERIES.x; tested $PYTHON_TESTED_VERSION)" ;;
  esac
}

check_optional_version() {
  local command=$1 expected=$2 observed
  if ! command_available "$command"; then
    optional "$command" "not installed; required only for optional deployment work"
    return
  fi
  observed=$(normalize_version "$(actual_version "$command")")
  if [[ "$observed" == "$expected" ]]; then
    optional "$command" "$observed (supported)"
  else
    optional "$command" "$observed (supported local baseline: $expected)"
  fi
}

printf 'Local environment doctor\n'
printf 'Platform: %s\n' "$platform"
printf 'Manifest: tools/versions.env\n\n'

for command in bash git make curl unzip sha256sum readlink; do
  check_presence "$command"
done

expected_venv=$(readlink -f -- "$REPO_ROOT/.venv" 2>/dev/null || true)
active_venv=$(readlink -f -- "${VIRTUAL_ENV:-}" 2>/dev/null || true)
if [[ -n "${VIRTUAL_ENV:-}" &&
      -n "$active_venv" &&
      "$active_venv" == "$expected_venv" &&
      -x "$active_venv/bin/python3" ]]; then
  pass "virtualenv" "repository .venv is active"
  export PATH="$active_venv/bin:$PATH"
else
  fail "virtualenv" "activate the repository .venv; unrelated or stale environments are unsupported"
fi

check_python_series
check_version node "$NODE_VERSION"
if command_available npm; then
  optional "npm" "available; bootstrap uses $NPM_VERSION transiently for Node-tool installation"
else
  optional "npm" "not installed; bootstrap-only and unnecessary after Node-tool installation"
fi
check_version terraform "$TERRAFORM_VERSION"
check_version tflint "$TFLINT_VERSION"
check_version checkov "$CHECKOV_VERSION"
check_version yamllint "$YAMLLINT_VERSION"
check_version shellcheck "$SHELLCHECK_VERSION"
check_version markdownlint "$MARKDOWNLINT_VERSION"
check_version pre-commit "$PRE_COMMIT_VERSION"
check_version jq "$JQ_VERSION"
check_version bats "$BATS_VERSION"

check_optional_version helm "$HELM_VERSION"
check_optional_version kubectl "$KUBECTL_VERSION"
check_optional_version kubeconform "$KUBECONFORM_VERSION"
for command in az kubelogin; do
  if command -v "$command" >/dev/null 2>&1; then
    optional "$command" "available; version not constrained for non-deployment validation"
  else
    optional "$command" "not installed; required only for optional deployment work"
  fi
done

autocrlf=$(git -C "$REPO_ROOT" config --get core.autocrlf 2>/dev/null || true)
if [[ "$autocrlf" == "true" ]]; then
  fail "line endings" "core.autocrlf=true; use input or false with repository LF attributes"
elif grep -q '^\* text=auto eol=lf$' "$REPO_ROOT/.gitattributes"; then
  pass "line endings" "repository enforces LF; core.autocrlf=${autocrlf:-unset}"
else
  fail "line endings" "missing repository-wide LF policy"
fi

if [[ "$CHECK_CONTAINER" == true ]]; then
  if ! command -v docker >/dev/null 2>&1; then
    fail "docker" "required for the requested container target"
  elif docker info >/dev/null 2>&1; then
    pass "docker" "daemon available"
  else
    fail "docker" "client found but daemon is unavailable"
  fi
fi

if ((failures)); then
  printf '\nDoctor: FAIL (%d prerequisite issue(s))\n' "$failures" >&2
  exit 1
fi
printf '\nDoctor: PASS\n'
