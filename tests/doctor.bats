#!/usr/bin/env bats

setup() {
  export TEST_ROOT="$BATS_TEST_TMPDIR/doctor"
  export TEST_BIN="$TEST_ROOT/bin"
  export TEST_VENV="$TEST_ROOT/venv"
  mkdir -p "$TEST_BIN" "$TEST_VENV/bin"
  touch "$TEST_VENV/bin/python3"
  chmod +x "$TEST_VENV/bin/python3"

  create_fixture_tools
  export PATH="$TEST_BIN:/usr/bin:/bin"
  export VIRTUAL_ENV="$TEST_VENV"
  export DOCTOR_TEST_MODE=1
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
  write_tool tflint 'printf "TFLint version 0.63.1\n"'
  write_tool checkov 'printf "3.3.8\n"'
  write_tool yamllint 'printf "yamllint 1.38.0\n"'
  write_tool shellcheck 'printf "ShellCheck - shell script analysis tool\nversion: 0.11.0\n"'
  write_tool markdownlint 'printf "0.49.0\n"'
  write_tool pre-commit 'printf "pre-commit 4.6.1\n"'
  write_tool jq 'printf "jq-1.8.1\n"'
  write_tool bats 'printf "Bats 1.14.0\n"'
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

@test "doctor rejects native Windows shells with guidance" {
  export DOCTOR_TEST_UNAME_S="MINGW64_NT-10.0"
  run bash scripts/doctor.sh
  [ "$status" -ne 0 ]
  [[ "$output" == *"Use WSL 2 or the Dev Container"* ]]
}
