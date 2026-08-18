#!/usr/bin/env bats

@test "bootstrap plan is deterministic and leaves the worktree unchanged" {
  before=$(git status --porcelain=v1 --untracked-files=normal)
  run bash scripts/bootstrap-local.sh --print-plan
  [ "$status" -eq 0 ]
  first=$output
  run bash scripts/bootstrap-local.sh --print-plan
  [ "$status" -eq 0 ]
  [ "$output" = "$first" ]
  after=$(git status --porcelain=v1 --untracked-files=normal)
  [ "$after" = "$before" ]
}

@test "bootstrap documents explicit user-local mode" {
  run bash scripts/bootstrap-local.sh --user --print-plan
  [ "$status" -eq 0 ]
  [[ "$output" == *"Mode: user"* ]]
  [[ "$output" == *".local"* ]]
}

make_preflight_path() {
  local omitted=${1:-}
  export PREFLIGHT_BIN="$BATS_TEST_TMPDIR/preflight-$omitted"
  mkdir -p "$PREFLIGHT_BIN"
  for command in awk bash chmod cp curl dirname git grep head install ln make mkdir mktemp mv python3 rm sha256sum tar uname unzip; do
    [[ "$command" == "$omitted" ]] && continue
    ln -s "$(command -v "$command")" "$PREFLIGHT_BIN/$command"
  done
}

@test "bootstrap accepts x86-64 during a no-write plan" {
  run bash scripts/bootstrap-local.sh --print-plan
  [ "$status" -eq 0 ]
  [[ "$output" == *"Mode: user"* ]]
}

@test "bootstrap rejects ARM64 before creating installation paths" {
  make_preflight_path
  rm "$PREFLIGHT_BIN/uname"
  printf '#!/usr/bin/env bash\n[[ "${1:-}" == "-s" ]] && printf "Linux\\n" || printf "aarch64\\n"\n' > "$PREFLIGHT_BIN/uname"
  chmod +x "$PREFLIGHT_BIN/uname"
  export HOME="$BATS_TEST_TMPDIR/arm-home"
  run env PATH="$PREFLIGHT_BIN" /bin/bash scripts/bootstrap-local.sh --print-plan
  [ "$status" -ne 0 ]
  [[ "$output" == *"x86-64/amd64 only"* ]]
  [ ! -e "$HOME/.local" ]
}

@test "bootstrap rejects an unknown architecture before writes" {
  make_preflight_path
  rm "$PREFLIGHT_BIN/uname"
  printf '#!/usr/bin/env bash\n[[ "${1:-}" == "-s" ]] && printf "Linux\\n" || printf "mips64\\n"\n' > "$PREFLIGHT_BIN/uname"
  chmod +x "$PREFLIGHT_BIN/uname"
  export HOME="$BATS_TEST_TMPDIR/unknown-home"
  run env PATH="$PREFLIGHT_BIN" /bin/bash scripts/bootstrap-local.sh --print-plan
  [ "$status" -ne 0 ]
  [ ! -e "$HOME/.local" ]
}

for_missing_prerequisite() {
  local missing=$1
  make_preflight_path "$missing"
  export HOME="$BATS_TEST_TMPDIR/missing-$missing-home"
  run env PATH="$PREFLIGHT_BIN" /bin/bash scripts/bootstrap-local.sh --print-plan
  [ "$status" -ne 0 ]
  [[ "$output" == *"$missing"* ]]
  [ ! -e "$HOME/.local" ]
}

@test "bootstrap rejects missing sha256sum without partial installation" {
  for_missing_prerequisite sha256sum
}

@test "bootstrap rejects missing install without partial installation" {
  for_missing_prerequisite install
}

@test "bootstrap rejects another mandatory prerequisite without partial installation" {
  for_missing_prerequisite unzip
}
