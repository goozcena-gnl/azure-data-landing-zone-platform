#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
IMAGE_NAME="azure-data-landing-zone-platform-dev:test-$$-${RANDOM}"

command -v docker >/dev/null 2>&1 || {
  printf 'ERROR: Docker is required only for make test-container.\n' >&2
  exit 1
}
docker info >/dev/null 2>&1 || {
  printf 'ERROR: Docker daemon is unavailable.\n' >&2
  exit 1
}

before_status=$(git -C "$REPO_ROOT" status --porcelain=v1 --ignored --untracked-files=all)
cleanup() {
  docker image rm --force "$IMAGE_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

docker build \
  --file "$REPO_ROOT/.devcontainer/Dockerfile" \
  --tag "$IMAGE_NAME" \
  "$REPO_ROOT"

git -C "$REPO_ROOT" ls-files --cached --others --exclude-standard -z |
  tar --directory "$REPO_ROOT" --null --files-from=- --create --file=- |
  docker run --rm --interactive \
    --workdir /workspace \
    "$IMAGE_NAME" \
    bash -lc 'mkdir repository && cd repository && tar -xf - && git init -q && git add -A && bash scripts/bootstrap-local.sh --python-only && source .venv/bin/activate && make doctor && make test-strict'

bash "$REPO_ROOT/scripts/scan-container.sh" "$IMAGE_NAME"

after_status=$(git -C "$REPO_ROOT" status --porcelain=v1 --ignored --untracked-files=all)
[[ "$after_status" == "$before_status" ]] || {
  printf 'ERROR: container validation changed the host repository filesystem.\n' >&2
  exit 1
}
