#!/usr/bin/env bats

setup() {
  export TEST_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$TEST_BIN"
  for command in python3 shellcheck markdownlint terraform tflint; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$TEST_BIN/$command"
    chmod +x "$TEST_BIN/$command"
  done
  export PATH="$TEST_BIN:/usr/bin:/bin"
}

@test "strict lint prerequisite check fails on a missing tool" {
  run bash scripts/lint.sh --strict --verify-tools-only
  [ "$status" -ne 0 ]
  [[ "$output" == *"yamllint"* ]]
}

@test "best-effort lint prerequisite check reports the skip and succeeds" {
  run bash scripts/lint.sh --best-effort --verify-tools-only
  [ "$status" -eq 0 ]
  [[ "$output" == *"Best-effort lint would skip: yamllint"* ]]
}

@test "strict repository-only mode delegates Terraform tools to the CI terraform job" {
  write_tool() {
    local name=$1
    printf '#!/usr/bin/env bash\nexit 0\n' > "$TEST_BIN/$name"
    chmod +x "$TEST_BIN/$name"
  }
  write_tool yamllint
  run bash scripts/lint.sh --strict --repository-only --verify-tools-only
  [ "$status" -eq 0 ]
  [[ "$output" == *"All lint prerequisites are available."* ]]
}
