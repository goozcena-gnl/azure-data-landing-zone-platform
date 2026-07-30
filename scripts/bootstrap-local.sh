#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
VERSIONS_FILE="$REPO_ROOT/tools/versions.env"
LOCK_FILE="$REPO_ROOT/requirements-dev.lock"

mode=user
python_only=false
print_plan=false

usage() {
  cat <<'EOF'
Usage: scripts/bootstrap-local.sh [--user|--system] [--python-only] [--print-plan]

Install the exact supported local-validation toolchain on Ubuntu/Debian Linux
or WSL 2. User mode writes under ~/.local and is the default. System mode must
be invoked explicitly as root, for example:

  sudo bash scripts/bootstrap-local.sh --system

The script never installs cloud credentials, authenticates to Azure, or runs
Terraform plan, apply, or destroy.
EOF
}

while (($#)); do
  case "$1" in
    --user) mode=user; shift ;;
    --system) mode=system; shift ;;
    --python-only) python_only=true; shift ;;
    --print-plan) print_plan=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

[[ -f "$VERSIONS_FILE" ]] || {
  printf 'ERROR: missing %s\n' "$VERSIONS_FILE" >&2
  exit 1
}
if grep -Ev '^\s*(#.*)?$|^[A-Z][A-Z0-9_]*=[A-Za-z0-9][A-Za-z0-9._:+-]*$' \
  "$VERSIONS_FILE" | grep -q .; then
  printf 'ERROR: unsafe assignment in %s\n' "$VERSIONS_FILE" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$VERSIONS_FILE"

[[ "$(uname -s)" == Linux ]] || {
  printf 'ERROR: bootstrap supports Linux and WSL 2 only.\n' >&2
  exit 1
}
[[ -r /etc/os-release ]] || {
  printf 'ERROR: /etc/os-release is unavailable.\n' >&2
  exit 1
}
# shellcheck disable=SC1091
source /etc/os-release
case "${ID:-}" in
  ubuntu|debian) ;;
  *)
    printf 'ERROR: automatic bootstrap supports Ubuntu/Debian only; found %s.\n' "${ID:-unknown}" >&2
    exit 1
    ;;
esac

if [[ "$mode" == system ]]; then
  [[ "$EUID" -eq 0 ]] || {
    printf 'ERROR: system mode must be explicitly run as root: sudo bash scripts/bootstrap-local.sh --system\n' >&2
    exit 1
  }
  prefix=/usr/local
else
  prefix="${HOME}/.local"
fi
bin_dir="$prefix/bin"
share_dir="$prefix/share"
cache_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/azure-data-landing-zone-platform/downloads"

plan() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

required_system=(bash git make curl unzip tar python3)
missing=()
for command in "${required_system[@]}"; do
  command -v "$command" >/dev/null 2>&1 || missing+=("$command")
done
if ((${#missing[@]})); then
  printf 'ERROR: required system commands are missing: %s\n' "${missing[*]}" >&2
  printf 'Ubuntu/Debian system-install command:\n' >&2
  printf '  sudo apt-get update && sudo apt-get install -y git make curl unzip tar python3 python3-venv\n' >&2
  exit 1
fi

actual_python=$(python3 --version 2>&1 | awk '{print $2}')
[[ "$actual_python" == "$PYTHON_VERSION" ]] ||
  die "Python $PYTHON_VERSION is required; found $actual_python. Install the supported Python before retrying."
[[ -f "$LOCK_FILE" ]] || die "Missing hashed Python lock file: requirements-dev.lock"

baseline_status=$(git -C "$REPO_ROOT" status --porcelain=v1 --untracked-files=normal)

plan "Mode: $mode"
plan "Install prefix: $prefix"
plan "Python: $PYTHON_VERSION -> .venv from requirements-dev.lock"
if [[ "$python_only" == false ]]; then
  plan "Node.js: $NODE_VERSION"
  plan "Terraform: $TERRAFORM_VERSION"
  plan "TFLint: $TFLINT_VERSION (AzureRM plugin $TFLINT_AZURERM_PLUGIN_VERSION)"
  plan "Markdownlint CLI: $MARKDOWNLINT_VERSION"
  plan "Helm: $HELM_VERSION"
  plan "kubectl: $KUBECTL_VERSION"
  plan "Kubeconform: $KUBECONFORM_VERSION"
  plan "jq: $JQ_VERSION"
  plan "Bats: $BATS_VERSION at $BATS_COMMIT"
fi
if [[ "$print_plan" == true ]]; then
  exit 0
fi

mkdir -p "$bin_dir" "$share_dir" "$cache_dir"
export PATH="$bin_dir:$PATH"

download_verified() {
  local url=$1 expected=$2 destination=$3 temporary
  temporary="${destination}.part"
  rm -f -- "$temporary"
  curl --proto '=https' --tlsv1.2 --fail --silent --show-error --location \
    --output "$temporary" "$url"
  printf '%s  %s\n' "$expected" "$temporary" | sha256sum --check --status ||
    die "Checksum verification failed for $url"
  mv -f -- "$temporary" "$destination"
}

install_zip_binary() {
  local url=$1 checksum=$2 archive_name=$3 binary_name=$4
  local archive="$cache_dir/$archive_name" temporary
  download_verified "$url" "$checksum" "$archive"
  temporary=$(mktemp -d)
  unzip -q "$archive" -d "$temporary"
  install -m 0755 "$temporary/$binary_name" "$bin_dir/$binary_name"
  rm -rf -- "$temporary"
}

install_tar_binary() {
  local url=$1 checksum=$2 archive_name=$3 member=$4 binary_name=$5
  local archive="$cache_dir/$archive_name" temporary
  download_verified "$url" "$checksum" "$archive"
  temporary=$(mktemp -d)
  tar -xzf "$archive" -C "$temporary"
  install -m 0755 "$temporary/$member" "$bin_dir/$binary_name"
  rm -rf -- "$temporary"
}

install_node() {
  local archive="$cache_dir/node-v${NODE_VERSION}-linux-x64.tar.gz"
  local temporary node_source node_target
  download_verified \
    "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz" \
    "$NODE_LINUX_AMD64_SHA256" \
    "$archive"
  temporary=$(mktemp -d)
  tar -xzf "$archive" -C "$temporary"
  node_source="$temporary/node-v${NODE_VERSION}-linux-x64"
  node_target="$share_dir/node/$NODE_VERSION"
  rm -rf -- "$node_target"
  mkdir -p "$(dirname "$node_target")"
  cp -a "$node_source" "$node_target"
  ln -sfn "$node_target/bin/node" "$bin_dir/node"
  ln -sfn "$node_target/lib/node_modules/npm/bin/npm-cli.js" "$bin_dir/npm"
  ln -sfn "$node_target/lib/node_modules/npm/bin/npx-cli.js" "$bin_dir/npx"
  rm -rf -- "$temporary"
}

venv_dir="$REPO_ROOT/.venv"
venv_python="$venv_dir/bin/python3"
venv_pip="$venv_dir/bin/pip"
venv_activate="$venv_dir/bin/activate"
expected_shebang="#!${venv_python}"
if [[ -e "$venv_dir" ]] &&
   { [[ ! -x "$venv_python" ]] ||
     [[ ! -f "$venv_pip" ]] ||
     [[ "$(head -n 1 "$venv_pip")" != "$expected_shebang" ]] ||
     [[ ! -f "$venv_activate" ]] ||
     ! grep -Fq "$venv_dir" "$venv_activate"; }; then
  python3 -m venv --clear "$venv_dir"
else
  python3 -m venv "$venv_dir"
fi
"$venv_python" -m pip install \
  --disable-pip-version-check \
  --no-input \
  --require-hashes \
  --requirement "$LOCK_FILE"

if [[ "$python_only" == false ]]; then
  install_node

  install_zip_binary \
    "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
    "$TERRAFORM_LINUX_AMD64_SHA256" \
    "terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
    terraform

  install_zip_binary \
    "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip" \
    "$TFLINT_LINUX_AMD64_SHA256" \
    "tflint_${TFLINT_VERSION}_linux_amd64.zip" \
    tflint

  install_tar_binary \
    "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
    "$HELM_LINUX_AMD64_SHA256" \
    "helm_${HELM_VERSION}_linux_amd64.tar.gz" \
    "linux-amd64/helm" \
    helm

  download_verified \
    "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    "$KUBECTL_LINUX_AMD64_SHA256" \
    "$bin_dir/kubectl"
  chmod 0755 "$bin_dir/kubectl"

  install_tar_binary \
    "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz" \
    "$KUBECONFORM_LINUX_AMD64_SHA256" \
    "kubeconform_${KUBECONFORM_VERSION}_linux_amd64.tar.gz" \
    kubeconform \
    kubeconform

  download_verified \
    "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-amd64" \
    "$JQ_LINUX_AMD64_SHA256" \
    "$bin_dir/jq"
  chmod 0755 "$bin_dir/jq"

  npm install --global --prefix "$prefix" "markdownlint-cli@${MARKDOWNLINT_VERSION}"

  bats_source="$share_dir/bats-core/$BATS_VERSION"
  if [[ -d "$bats_source/.git" ]]; then
    observed=$(git -C "$bats_source" rev-parse HEAD)
    [[ "$observed" == "$BATS_COMMIT" ]] ||
      die "Existing Bats source has unexpected commit $observed"
  else
    rm -rf -- "$bats_source"
    mkdir -p "$(dirname "$bats_source")"
    git clone --filter=blob:none --branch "v${BATS_VERSION}" --depth 1 \
      https://github.com/bats-core/bats-core.git "$bats_source"
    observed=$(git -C "$bats_source" rev-parse HEAD)
    [[ "$observed" == "$BATS_COMMIT" ]] ||
      die "Downloaded Bats source has unexpected commit $observed"
  fi
  "$bats_source/install.sh" "$prefix"

  (
    cd "$REPO_ROOT"
    "$bin_dir/tflint" --init
  )
fi

final_status=$(git -C "$REPO_ROOT" status --porcelain=v1 --untracked-files=normal)
[[ "$final_status" == "$baseline_status" ]] ||
  die "Bootstrap changed the tracked or untracked Git worktree unexpectedly."

printf '\nBootstrap complete. Activate the environment before validation:\n'
printf '  source .venv/bin/activate\n'
# shellcheck disable=SC2016
printf '  export PATH="%s:$PATH"\n' "$bin_dir"
printf '  make doctor\n'
