#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
cd "${REPO_ROOT}"

require_command python3
python3 tests/repository_policy.py

if command -v yamllint >/dev/null 2>&1; then
  mapfile -t yaml_files < <(find . -type f \( -name '*.yml' -o -name '*.yaml' \) -not -path './.git/*' -print)
  ((${#yaml_files[@]} == 0)) || yamllint -c .yamllint.yml "${yaml_files[@]}"
else
  log 'yamllint not installed; YAML lint skipped.'
fi

mapfile -t shell_files < <(
  find scripts terraform_backend_setup -type f -name '*.sh' -print
)
for file in "${shell_files[@]}"; do bash -n "$file"; done
if command -v shellcheck >/dev/null 2>&1; then shellcheck -x "${shell_files[@]}"; else log 'shellcheck not installed; shell lint skipped.'; fi

if command -v markdownlint >/dev/null 2>&1; then
  markdownlint --config .markdownlint.json '**/*.md' --ignore '.git/**' --ignore '.venv/**'
else
  log 'markdownlint not installed; Markdown lint skipped.'
fi

if command -v terraform >/dev/null 2>&1; then terraform fmt -check -recursive; else log 'terraform not installed; terraform fmt skipped.'; fi
if command -v tflint >/dev/null 2>&1; then tflint --init && tflint --recursive; else log 'tflint not installed; TFLint skipped.'; fi
