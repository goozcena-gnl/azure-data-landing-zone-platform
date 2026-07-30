#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
cd "${REPO_ROOT}"

mode=strict
verify_tools_only=false
repository_only=false
while (($#)); do
  case "$1" in
    --strict) mode=strict; shift ;;
    --best-effort) mode=best-effort; shift ;;
    --repository-only) repository_only=true; shift ;;
    --verify-tools-only) verify_tools_only=true; shift ;;
    *) die "Unknown lint argument: $1" ;;
  esac
done

missing=()
required_commands=(python3 yamllint shellcheck markdownlint)
if [[ "$repository_only" == false ]]; then
  required_commands+=(terraform tflint)
fi
for command in "${required_commands[@]}"; do
  command -v "$command" >/dev/null 2>&1 || missing+=("$command")
done
if ((${#missing[@]})) && [[ "$mode" == strict ]]; then
  die "Strict lint prerequisites missing: ${missing[*]}. Run 'make bootstrap' and activate .venv."
fi
if [[ "$verify_tools_only" == true ]]; then
  if ((${#missing[@]})); then
    printf 'Best-effort lint would skip: %s\n' "${missing[*]}"
  else
    printf 'All lint prerequisites are available.\n'
  fi
  exit 0
fi

require_command python3
python3 tests/repository_policy.py

if command -v yamllint >/dev/null 2>&1; then
  mapfile -d '' -t yaml_files < <(
    git ls-files --cached --others --exclude-standard -z -- '*.yml' '*.yaml'
  )
  ((${#yaml_files[@]} == 0)) || yamllint -c .yamllint.yml "${yaml_files[@]}"
else
  log 'BEST EFFORT: yamllint not installed; YAML lint skipped.'
fi

mapfile -t shell_files < <(
  find scripts terraform_backend_setup -type f -name '*.sh' -print
)
for file in "${shell_files[@]}"; do bash -n "$file"; done
if command -v shellcheck >/dev/null 2>&1; then shellcheck -x "${shell_files[@]}"; else log 'BEST EFFORT: shellcheck not installed; shell lint skipped.'; fi

if command -v markdownlint >/dev/null 2>&1; then
  markdownlint --config .markdownlint.json '**/*.md' --ignore '.git/**' --ignore '.venv/**'
else
  log 'BEST EFFORT: markdownlint not installed; Markdown lint skipped.'
fi

if [[ "$repository_only" == false ]]; then
  if command -v terraform >/dev/null 2>&1; then terraform fmt -check -recursive; else log 'BEST EFFORT: terraform not installed; terraform fmt skipped.'; fi
  if command -v tflint >/dev/null 2>&1; then tflint --init && tflint --recursive; else log 'BEST EFFORT: TFLint not installed; TFLint skipped.'; fi
fi
