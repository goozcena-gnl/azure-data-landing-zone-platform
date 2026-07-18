#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
VERSION="v0.1.0"
OUTPUT_DIR=""

usage() {
  cat <<'EOF'
Usage: scripts/package-release.sh --output-dir PATH [--version LABEL]

Create and re-extract a GitHub-ready ZIP from committed files at HEAD only.
The output directory must be outside the repository.

Outputs:
  azure-data-landing-zone-platform-<version>.zip
  file-manifest.csv
  SHA256SUMS

The manifest records path, byte size, SHA-256, and publication category.
EOF
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --output-dir) [[ $# -ge 2 ]] || die "Missing value for --output-dir."; OUTPUT_DIR=$2; shift 2 ;;
    --version) [[ $# -ge 2 ]] || die "Missing value for --version."; VERSION=$2; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

for command in git sha256sum unzip python3 terraform make bash; do
  command -v "$command" >/dev/null 2>&1 || die "Required command not found: $command"
done
[[ -n "$OUTPUT_DIR" ]] || die "--output-dir is required."
[[ "$VERSION" =~ ^[A-Za-z0-9._-]+$ ]] || die "Version label contains unsupported characters."

cd "$REPO_ROOT"
repo_top=$(git rev-parse --show-toplevel)
[[ "$repo_top" == "$REPO_ROOT" ]] || die "Repository root mismatch."
[[ -z "$(git status --porcelain --untracked-files=normal)" ]] ||
  die "Release packaging requires a clean worktree."

mkdir -p "$OUTPUT_DIR"
output_real=$(cd "$OUTPUT_DIR" && pwd -P)
case "$output_real/" in
  "$REPO_ROOT/"*) die "Output directory must be outside the repository." ;;
esac

package_name="azure-data-landing-zone-platform-${VERSION}"
archive="$output_real/${package_name}.zip"
manifest="$output_real/file-manifest.csv"
checksums="$output_real/SHA256SUMS"
[[ ! -e "$archive" && ! -e "$manifest" && ! -e "$checksums" ]] ||
  die "One or more release outputs already exist; use an empty output directory."

tracked_list=$(git ls-tree -r --name-only HEAD)
[[ -n "$tracked_list" ]] || die "HEAD contains no tracked files."

if grep -E '(^|/)(\.git|\.terraform)(/|$)|(^|/)(backend\.hcl|terraform\.tfvars|tfplan|kubeconfig)(/|$)|\.tfplan$|\.tfstate($|\.)|(^|/)\.env($|/)' \
  <<< "$tracked_list"; then
  die "HEAD contains a forbidden release artifact."
fi

category_for() {
  case "$1" in
    .github/*) printf 'github-automation\n' ;;
    .azuredevops/*) printf 'azure-devops-automation\n' ;;
    docs/*) printf 'documentation\n' ;;
    infra/*) printf 'infrastructure-as-code\n' ;;
    platform/*) printf 'platform-configuration\n' ;;
    scripts/*) printf 'automation-script\n' ;;
    tests/*|terraform_backend_setup/tests/*) printf 'test\n' ;;
    terraform_backend_setup/*) printf 'backend-bootstrap\n' ;;
    *) printf 'repository-metadata\n' ;;
  esac
}

csv_escape() {
  local value=${1//\"/\"\"}
  printf '"%s"' "$value"
}

printf 'path,size,sha256,publication_category\n' > "$manifest"
file_count=0
while IFS= read -r path; do
  [[ -n "$path" ]] || continue
  size=$(git cat-file -s "HEAD:$path")
  sha=$(git show "HEAD:$path" | sha256sum | awk '{print $1}')
  category=$(category_for "$path")
  {
    csv_escape "$path"
    printf ',%s,%s,' "$size" "$sha"
    csv_escape "$category"
    printf '\n'
  } >> "$manifest"
  file_count=$((file_count + 1))
done <<< "$tracked_list"

git archive --format=zip --prefix="${package_name}/" --output="$archive" HEAD

(
  cd "$output_real"
  sha256sum "$(basename "$archive")" "$(basename "$manifest")" > "$(basename "$checksums")"
  sha256sum -c "$(basename "$checksums")"
)

temp_root=$(mktemp -d "/tmp/azure-dlz-package.XXXXXX")
cleanup() {
  case "$temp_root" in
    /tmp/azure-dlz-package.*) rm -rf -- "$temp_root" ;;
    *) printf 'WARNING: refusing to remove unexpected temporary path: %s\n' "$temp_root" >&2 ;;
  esac
}
trap cleanup EXIT

unzip -q "$archive" -d "$temp_root"
extracted_root="$temp_root/$package_name"
[[ -d "$extracted_root" ]] || die "Expected extracted root is missing."

if find "$extracted_root" \
  \( -name .git -o -name .terraform -o -name '*.tfplan' -o -name '*.tfstate' \
     -o -name 'terraform.tfvars' -o -name backend.hcl -o -name kubeconfig \) \
  -print -quit | grep -q .; then
  die "Extracted archive contains a forbidden artifact."
fi

(
  cd "$extracted_root"
  python3 tests/repository_policy.py
  python3 scripts/secret-scan.py --root .
  python3 scripts/check-doc-links.py
  terraform fmt -check -recursive
  find scripts terraform_backend_setup -type f -name '*.sh' -exec bash -n {} +
  make backend-test
  make terraform-test
  make validate
  if command -v checkov >/dev/null 2>&1; then
    make security
  else
    printf 'BLOCKED: Checkov is not available in the package-validation PATH.\n' >&2
    exit 1
  fi
  if command -v shellcheck >/dev/null 2>&1; then
    find scripts terraform_backend_setup -type f -name '*.sh' -exec shellcheck -x {} +
  else
    printf 'BLOCKED: ShellCheck is not available in the package-validation PATH.\n' >&2
    exit 1
  fi
  if command -v yamllint >/dev/null 2>&1; then
    find . -type f \( -name '*.yml' -o -name '*.yaml' \) -exec yamllint -c .yamllint.yml {} +
  else
    printf 'BLOCKED: Yamllint is not available in the package-validation PATH.\n' >&2
    exit 1
  fi
  if command -v tflint >/dev/null 2>&1; then
    tflint --recursive
  else
    printf 'BLOCKED: TFLint is not available in the package-validation PATH.\n' >&2
    exit 1
  fi
)

archive_size=$(stat -c '%s' "$archive")
printf '\nRelease package verified.\n'
printf 'Archive: %s\n' "$archive"
printf 'Files: %d\n' "$file_count"
printf 'Archive bytes: %s\n' "$archive_size"
printf 'Manifest: %s\n' "$manifest"
printf 'Checksums: %s\n' "$checksums"
