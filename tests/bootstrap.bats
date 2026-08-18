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
