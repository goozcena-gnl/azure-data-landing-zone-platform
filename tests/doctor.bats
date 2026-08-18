#!/usr/bin/env bats

setup() {
  export TEST_ROOT="$BATS_TEST_TMPDIR/doctor"
  export TEST_BIN="$TEST_ROOT/bin"
  export TEST_REPO="$TEST_ROOT/repository"
  export TEST_VENV="$TEST_REPO/.venv"
  mkdir -p "$TEST_BIN" "$TEST_VENV/bin"
  mkdir -p "$TEST_REPO/tools"
  cp tools/versions.env "$TEST_REPO/tools/versions.env"
  printf '* text=auto eol=lf\n' > "$TEST_REPO/.gitattributes"
  printf '#!/usr/bin/env bash\nprintf "Python 3.12.3\\n"\n' > "$TEST_VENV/bin/python3"
  chmod +x "$TEST_VENV/bin/python3"

  create_fixture_tools
  export PATH="$TEST_BIN:/usr/bin:/bin"
  export VIRTUAL_ENV="$TEST_VENV"
  export DOCTOR_TEST_MODE=1
  export DOCTOR_TEST_REPO_ROOT="$TEST_REPO"
  export DOCTOR_TEST_UNAME_S=Linux
  export DOCTOR_TEST_PROC_VERSION=Linux
}

write_tool() {
  local name=$1 body=$2
  printf '#!/usr/bin/env bash\n%s\n' "$body" > "$TEST_BIN/$name"
  chmod +x "$TEST_BIN/$name"
}

create_fixture_tools() {
  write_tool git '[[ "${1:-}" == "-C" ]] && exit 1; exit 0'
  write_tool make 'exit 0'
  write_tool curl 'exit 0'
  write_tool unzip 'exit 0'
  write_tool sha256sum 'exit 0'
  write_tool python3 'printf "Python 3.12.3\n"'
  write_tool node 'printf "v24.18.1\n"'
  write_tool terraform 'printf "Terraform v1.15.8\n"'
  write_tool npm 'printf "12.0.2\n"'
  write_tool tflint 'printf "TFLint version 0.64.0\n"'
  write_tool checkov 'printf "3.3.8\n"'
  write_tool yamllint 'printf "yamllint 1.38.0\n"'
  write_tool shellcheck 'printf "ShellCheck - shell script analysis tool\nversion: 0.11.0\n"'
  write_tool markdownlint 'printf "0.49.1\n"'
  write_tool pre-commit 'printf "pre-commit 4.6.1\n"'
  write_tool jq 'printf "jq-1.8.1\n"'
  write_tool bats 'printf "Bats 1.14.0\n"'
}

@test "doctor accepts the exact canonical repository venv" {
  run bash scripts/doctor.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"repository .venv is active"* ]]
}

@test "doctor accepts a symlink resolving to the repository venv" {
  ln -s "$TEST_VENV" "$TEST_ROOT/venv-link"
  export VIRTUAL_ENV="$TEST_ROOT/venv-link"
  run bash scripts/doctor.sh
  [ "$status" -eq 0 ]
}

@test "doctor rejects an unrelated active venv" {
  mkdir -p "$TEST_ROOT/unrelated/bin"
  touch "$TEST_ROOT/unrelated/bin/python3"
  chmod +x "$TEST_ROOT/unrelated/bin/python3"
  export VIRTUAL_ENV="$TEST_ROOT/unrelated"
  run bash scripts/doctor.sh
  [ "$status" -ne 0 ]
  [[ "$output" == *"unrelated or stale"* ]]
}

@test "doctor rejects a missing repository venv" {
  rm -rf "$TEST_VENV"
  run bash scripts/doctor.sh
  [ "$status" -ne 0 ]
}

@test "doctor rejects a stale VIRTUAL_ENV path" {
  export VIRTUAL_ENV="$TEST_ROOT/does-not-exist"
  run bash scripts/doctor.sh
  [ "$status" -ne 0 ]
}

@test "doctor succeeds with the supported strict toolchain" {
  run bash scripts/doctor.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"Doctor: PASS"* ]]
}

@test "doctor fails when a required tool is missing" {
  export DOCTOR_TEST_MISSING_COMMAND=terraform
  run bash scripts/doctor.sh
  [ "$status" -ne 0 ]
  [[ "$output" == *"terraform"* ]]
  [[ "$output" == *"executable is missing"* ]]
}

@test "doctor identifies WSL 2" {
  export DOCTOR_TEST_PROC_VERSION="5.15.0-microsoft-standard-WSL2"
  run bash scripts/doctor.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"Platform: WSL 2"* ]]
}

@test "doctor rejects WSL 1-like metadata" {
  export DOCTOR_TEST_PROC_VERSION="4.4.0-19041-Microsoft"
  run bash scripts/doctor.sh
  [ "$status" -ne 0 ]
  [[ "$output" == *"WSL 1 is unsupported"* ]]
}

@test "doctor accepts ordinary Linux independently" {
  export DOCTOR_TEST_PROC_VERSION="6.8.0-generic"
  run bash scripts/doctor.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"Platform: Linux"* ]]
}

@test "doctor rejects native Windows shells with guidance" {
  export DOCTOR_TEST_UNAME_S="MINGW64_NT-10.0"
  run bash scripts/doctor.sh
  [ "$status" -ne 0 ]
  [[ "$output" == *"Use WSL 2 or the Dev Container"* ]]
}
