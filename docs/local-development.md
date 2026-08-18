# Local development

This guide reproduces every non-deployment validation category used by the
repository. It supports Ubuntu/Debian Linux, Windows 11 with WSL 2, and the
VS Code Dev Container.

None of these paths authenticates to Azure or runs Terraform plan, apply, or
destroy. They do not emulate Azure, AKS, Microsoft Entra, GitHub OIDC, GitHub
environments, or the self-hosted deployment runner.

## Supported toolchain

[`tools/versions.env`](../tools/versions.env) is the human-readable source of
truth. Repository policy fails when an active CI or local installation pin
drifts from it.

| Tool | Supported version | Local-validation role |
| --- | ---: | --- |
| Terraform | 1.15.8 | Formatting, backend-disabled validation, mocked tests |
| TFLint | 0.63.1 | Terraform lint |
| TFLint AzureRM rules | 0.28.0 | AzureRM static rules |
| Python | 3.12.3 | Policy, security, documentation, and Checkov |
| Node.js | 24.18.1 | Exact Markdownlint CLI installation and execution |
| Checkov | 3.3.8 | IaC security checks |
| Yamllint | 1.38.0 | YAML lint |
| ShellCheck | 0.11.0 | Shell static analysis |
| Markdownlint CLI | 0.49.0 | Markdown lint |
| pre-commit | 4.6.1 | Contributor hook runner |
| Helm | 4.2.3 | Optional deployment tooling |
| kubectl | 1.35.1 | Optional deployment tooling |
| Kubeconform | 0.8.0 | Optional Kubernetes manifest validation |
| jq | 1.8.1 | Backend-helper fixture parsing and regression tests |
| Bats Core | 1.14.0 | Shell regression tests |

Terraform provider lock files currently select AzureRM 4.81.0 and Random
3.9.0. Bootstrap does not update provider locks.

## Common prerequisites

- x86-64 Ubuntu 24.04 or Debian-compatible Linux;
- Git, Bash, Make, `curl`, `unzip`, `tar`, and `sha256sum`;
- Python 3.12.3 with the `venv` module;
- no preinstalled Node.js or npm; bootstrap installs the native Linux runtime;
- network access for the first bootstrap, provider/plugin initialization,
  pre-commit environments, and Dev Container build.

Docker is optional. It is checked only by `make test-container` or
`make doctor` with the container option.

## WSL 2 native setup

Enable WSL 2 and install Ubuntu 24.04. Clone into the Linux filesystem for the
best file-system performance:

```bash
git clone https://github.com/goozcena-gnl/azure-data-landing-zone-platform.git
cd azure-data-landing-zone-platform
bash scripts/bootstrap-local.sh
source .venv/bin/activate
export PATH="$HOME/.local/bin:$PATH"
make doctor
make test-strict
```

If a required Ubuntu package is missing, bootstrap stops and prints the exact
system-install command. It never invokes `sudo` in its default user-local mode.

Avoid running project scripts from PowerShell, Command Prompt, Git Bash, MSYS,
or Cygwin. `make doctor` rejects those native Windows shell environments and
directs contributors to WSL 2 or the Dev Container.

## Native Linux setup

On an x86-64 Ubuntu/Debian host:

```bash
git clone https://github.com/goozcena-gnl/azure-data-landing-zone-platform.git
cd azure-data-landing-zone-platform
make bootstrap
source .venv/bin/activate
export PATH="$HOME/.local/bin:$PATH"
make doctor
make test-strict
```

The default installer writes binaries under `~/.local`, Python packages under
the ignored repository `.venv`, and downloads under the cache directory. It
verifies downloaded binary checksums before installation.

System-wide installation is opt-in:

```bash
sudo bash scripts/bootstrap-local.sh --system
```

Do not use system mode on a shared machine without reviewing the script and
current manifest.

## VS Code Dev Container

Prerequisites:

- VS Code;
- the Dev Containers extension;
- a running Docker-compatible daemon.

Open the clone in VS Code and choose **Dev Containers: Reopen in Container**.
The image:

- uses an immutable Ubuntu 24.04 x86-64 image digest;
- runs as the image's non-root `ubuntu` user;
- installs exact manifest versions;
- mounts no Docker socket by default;
- uses neither privileged nor host-network mode;
- contains no credential or Azure login step.

The post-create command installs the hashed Python environment and runs the
doctor. To reproduce the same image and strict validation without VS Code:

```bash
make test-container
```

Docker is not required for WSL 2 or native-Linux contributors.

## Bootstrap behavior

`make bootstrap` is idempotent:

- an existing `.venv` is synchronized from `requirements-dev.lock` with
  required hashes;
- verified binaries replace only the matching user-local tool paths;
- Bats source is pinned to an immutable commit;
- the exact TFLint AzureRM plugin is initialized from `.tflint.hcl`;
- tracked and ordinary untracked Git status must be identical before and after.

Inspect the deterministic plan without changing the machine:

```bash
bash scripts/bootstrap-local.sh --print-plan
```

Install only the Python environment, as used by the Dev Container:

```bash
bash scripts/bootstrap-local.sh --python-only
```

Bootstrap never installs Azure credentials, calls `az login`, initializes a
real Terraform backend, or runs plan, apply, or destroy.

## Doctor

Activate `.venv`, place the selected installation prefix on `PATH`, then run:

```bash
make doctor
```

Doctor performs no network access and reports installed and expected versions.
It verifies:

- Linux or WSL 2 execution;
- all strict-validation executables;
- active Python virtual environment;
- repository LF line-ending policy;
- optional deployment-tool availability without making it a strict-validation
  prerequisite.

It never prints credentials or environment-variable values.

For a container prerequisite check:

```bash
bash scripts/doctor.sh --container
```

## Strict validation

Run the complete non-deployment parity gate:

```bash
make test-strict
```

It includes:

- repository and version-drift policy;
- Yamllint, ShellCheck, and Markdownlint;
- Terraform format;
- backend-disabled Terraform initialization and validation;
- provider-mocked Terraform tests;
- TFLint initialization and recursive checks;
- Checkov and deterministic secret scanning;
- documentation-link validation;
- backend-helper standalone regressions;
- local-environment and existing backend Bats tests.

Missing required tools fail immediately. For exploratory work only:

```bash
make lint-best-effort
```

Every skip is explicit. `make lint` and `make test` remain strict aliases.
The GitHub workflow uses the script's strict repository-only mode in its
repository job because pinned Terraform and TFLint checks run in the separate
Terraform job; the full local target does not use that scoped mode.

## pre-commit

After bootstrap and activation:

```bash
pre-commit install
pre-commit run --all-files
```

Hook installation changes only local Git metadata. The Yamllint hook is aligned
with the 1.38.0 manifest baseline.

## Cache locations

| Content | Default location |
| --- | --- |
| Python environment | `.venv/` |
| User-local binaries | `~/.local/bin/` |
| Bootstrap downloads | `${XDG_CACHE_HOME:-~/.cache}/azure-data-landing-zone-platform/downloads/` |
| Terraform working data | `${TF_DATA_ROOT:-${XDG_CACHE_HOME:-~/.cache}/azure-data-landing-zone-platform/terraform}` |
| TFLint plugins | TFLint's user cache under the home directory |
| pre-commit environments | `${PRE_COMMIT_HOME:-~/.cache/pre-commit}` |

All repository-local generated paths are ignored.

## Cleanup

Remove only local development state:

```bash
rm -rf .venv
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/azure-data-landing-zone-platform"
pre-commit clean
```

User-local tools under `~/.local` may be shared with other projects; inspect
them before removal. Container images can be removed through the Docker CLI.
None of these cleanup actions touches Azure.

## Windows line endings and executable bits

The repository enforces LF through `.gitattributes`. Recommended Windows Git
configuration:

```bash
git config --global core.autocrlf input
```

If Bash reports a `^M` interpreter error, restore the affected file from Git
after correcting `core.autocrlf`. Shell scripts must retain executable mode:

```bash
git ls-files --stage '*.sh'
```

Mode `100755` is expected for executable scripts. Do not repair line endings
with tools that rewrite unrelated files.

## Offline and network-required checks

Offline after caches are populated:

- doctor;
- repository and version-drift policy;
- shell syntax and static linters;
- deterministic secret scan;
- documentation-link checks;
- backend helper and Bats fixtures;
- Terraform format.

Network is required for:

- first bootstrap downloads;
- Python dependency installation;
- initial Terraform provider initialization;
- initial TFLint plugin initialization;
- pre-commit environment creation;
- Dev Container image build.

Terraform validation uses `-backend=false`. No local validation target contacts
Azure.

## Local validation boundaries

Local success does not prove:

- Azure authentication, authorization, quotas, policies, or API behavior;
- real remote-state initialization or locking;
- an Azure Terraform plan, apply, destroy, or drift result;
- AKS provisioning, Microsoft Entra integration, Workload Identity, or OIDC;
- JupyterHub deployment or runtime health;
- GitHub environments, approvals, OIDC exchange, artifacts, or self-hosted
  runner behavior.

Those operations require explicit, separate authorization and evidence.
