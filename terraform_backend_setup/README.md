# Azure Terraform backend bootstrap

Files:

- `terraform_setup.sh`: secure, idempotent Azure backend bootstrap.
- `.env.example`: non-sensitive configuration example.
- `tests/terraform_setup.bats`: sample Bats tests using a mocked Azure CLI.
- `tests/regression.sh`: dependency-light executable regression suite.

Required runtime commands are Azure CLI 2.26 or later, `jq`, `diff`, `awk`,
`sort`, `tr`, and a SHA-256 implementation. Azure CLI 2.88.0 compatibility was
verified locally.

Run:

```bash
bash -n terraform_setup.sh tests/regression.sh
bash tests/regression.sh
./terraform_setup.sh --help
```

The standalone suite covers scoped direct and inherited role assignments, zero
and unrelated assignments, multiline Storage JSON, `false`, `null`, missing
and malformed values, Azure CLI errors, required hardening, and repeat-run
idempotence. The same suite is called from Bats and CI.

Additional tools can provide deeper style validation:

```bash
shellcheck terraform_setup.sh tests/regression.sh
bats tests/terraform_setup.bats
```

The helper never combines `az role assignment list --all` with `--scope`.
Scoped discovery uses object IDs, explicit roles, structured JSON, and
intentional inherited-assignment filtering before any role creation.
