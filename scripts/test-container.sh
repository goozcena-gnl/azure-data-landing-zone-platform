#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
IMAGE_NAME=azure-data-landing-zone-platform-dev:local

command -v docker >/dev/null 2>&1 || {
  printf 'ERROR: Docker is required only for make test-container.\n' >&2
  exit 1
}
docker info >/dev/null 2>&1 || {
  printf 'ERROR: Docker daemon is unavailable.\n' >&2
  exit 1
}

docker build \
  --file "$REPO_ROOT/.devcontainer/Dockerfile" \
  --tag "$IMAGE_NAME" \
  "$REPO_ROOT"

docker run --rm \
  --volume "$REPO_ROOT:/workspace:rw" \
  --tmpfs /workspace/.venv:rw,exec,uid=1000,gid=1000,mode=0755 \
  --workdir /workspace \
  "$IMAGE_NAME" \
  bash -lc 'bash scripts/bootstrap-local.sh --python-only && source .venv/bin/activate && make doctor && make test-strict'
