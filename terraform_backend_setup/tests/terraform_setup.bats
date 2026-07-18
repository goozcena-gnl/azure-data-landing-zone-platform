#!/usr/bin/env bats

setup() {
  export TEST_ROOT="$BATS_TEST_TMPDIR/work"
  mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/out"
  export AZ_LOG="$TEST_ROOT/az.log"
  export SCRIPT="$BATS_TEST_DIRNAME/../terraform_setup.sh"

  cat > "$TEST_ROOT/bin/az" <<'AZ'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "${AZ_LOG:?}"
case "$1 $2" in
  "version --query") printf '2.80.0\n' ;;
  "account show")
    case "$*" in
      *"--query id"*) printf '00000000-0000-0000-0000-000000000000\n' ;;
      *"--query tenantId"*) printf '11111111-1111-1111-1111-111111111111\n' ;;
      *"--query user.name"*) printf 'user@example.com\n' ;;
      *"--query user.type"*) printf 'user\n' ;;
      *) printf '{}\n' ;;
    esac ;;
  "account set") : ;;
  "account list-locations") printf '1\n' ;;
  "group exists") printf 'false\n' ;;
  "storage account")
    case "$3" in
      show) exit 3 ;;
      list) printf '\n' ;;
      check-name)
        if [[ "$*" == *"--query nameAvailable"* ]]; then printf 'true\n'; else printf '\n'; fi
        ;;
      *) exit 9 ;;
    esac ;;
  "ad signed-in-user") exit 3 ;;
  *) echo "Unhandled mock az call: $*" >&2; exit 9 ;;
esac
AZ
  chmod +x "$TEST_ROOT/bin/az"
  export PATH="$TEST_ROOT/bin:$PATH"
}

base_args() {
  printf '%s\n' \
    --subscription-id 00000000-0000-0000-0000-000000000000 \
    --tenant-id 11111111-1111-1111-1111-111111111111 \
    --project platform \
    --environment dev \
    --client-ip 203.0.113.10 \
    --backend-file "$TEST_ROOT/out/backend.tf" \
    --backend-config-file "$TEST_ROOT/out/backend.hcl"
}

@test "help succeeds without Azure calls" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "unknown argument is rejected" {
  run "$SCRIPT" --unknown
  [ "$status" -ne 0 ]
  [[ "$output" == *"Argument inconnu"* ]]
}

@test "dry-run performs no Azure mutations and writes no files" {
  mapfile -t args < <(base_args)
  run "$SCRIPT" "${args[@]}" --dry-run
  [ "$status" -eq 0 ]
  [ ! -e "$TEST_ROOT/out/backend.tf" ]
  [ ! -e "$TEST_ROOT/out/backend.hcl" ]
  ! grep -Eq '^(group create|storage account create|tag update|role assignment create)' "$AZ_LOG"
}

@test "deterministic Storage name is stable" {
  mapfile -t args < <(base_args)
  run "$SCRIPT" "${args[@]}" --dry-run
  [ "$status" -eq 0 ]
  first=$(sed -n 's/^.*Nom Storage cible: //p' <<< "$output" | tail -1)
  [ -n "$first" ]

  run "$SCRIPT" "${args[@]}" --dry-run
  [ "$status" -eq 0 ]
  second=$(sed -n 's/^.*Nom Storage cible: //p' <<< "$output" | tail -1)
  [ "$first" = "$second" ]
}

@test "dry-run shows a differing backend file without overwriting it" {
  printf 'existing\n' > "$TEST_ROOT/out/backend.tf"
  before=$(sha256sum "$TEST_ROOT/out/backend.tf" | awk '{print $1}')
  mapfile -t args < <(base_args)

  run "$SCRIPT" "${args[@]}" --dry-run
  [ "$status" -eq 0 ]
  after=$(sha256sum "$TEST_ROOT/out/backend.tf" | awk '{print $1}')
  [ "$before" = "$after" ]
  [[ "$output" == *"serait remplacé avec --force"* ]]
}

@test "structured backend-helper regressions pass" {
  run "$BATS_TEST_DIRNAME/regression.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 failed"* ]]
}
