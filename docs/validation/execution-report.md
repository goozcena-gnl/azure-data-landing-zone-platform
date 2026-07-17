# Validation execution report

- Date: 2026-07-14 UTC
- Environment: isolated Linux build container; no Azure credentials
- Subject: sanitized `azure-data-landing-zone-platform` working copy
- Python: 3.13.5
- HCL parser: python-hcl2 7.3.1
- Checkov: 3.3.8
- Yamllint: 1.37.1
- ShellCheck: 0.11.0

## Results

| Test | Command | Status | Evidence | Limitation |
| --- | --- | ---: | --- | --- |
| Original archive extraction and inventory | Phase 1 audit | PASS | 2,317 entries; 2,051 regular files; 572.68 MiB | Original archive only |
| Repository publication policy | `python3 tests/repository_policy.py` | PASS | no forbidden state, plans, binaries, nested Git metadata, key markers, oversized files, or mutable GitHub Action refs | Static file policy only |
| Bash parsing | `bash -n scripts/*.sh` | PASS | every retained shell script parsed | No Azure operation executed |
| ShellCheck | `shellcheck -x scripts/*.sh` | PASS | exit 0 | Static shell analysis |
| YAML lint | `yamllint .` | PASS | exit 0 | Does not validate GitHub/Azure service semantics |
| Local documentation links | `python3 scripts/check-doc-links.py` | PASS | no broken local Markdown target | External links not crawled |
| Deterministic secret-pattern scan | `python3 scripts/secret-scan.py --root .` | PASS | zero findings | Heuristic scan; Git history does not yet exist |
| HCL syntax parse | python-hcl2 over all `.tf` files | PASS | 25 Terraform files parsed | Not provider-schema-aware |
| Checkov Terraform scan | `make security` | PASS | 44 checks passed; 0 failed | 13 lab-only exceptions are documented and excluded; static analysis only |
| Make command surface | `make help` | PASS | documented targets resolve | Does not execute blocked targets |
| Combined local lint wrapper | `make lint` | PASS | repository/YAML/shell checks passed | Terraform, TFLint, and Markdownlint were explicitly skipped because their CLIs were unavailable |
| Git staging and whitespace policy | `git init && git add . && git diff --cached --check` | PASS | all 93 files staged cleanly in an ephemeral local repository | Git history and remote protections do not yet exist |
| Clean package re-extraction | extract ZIP and rerun repository/secret/link/YAML/shell/HCL/Git checks | PASS | fresh extraction passed; 93 files staged | Provider-aware and Azure checks remain blocked |
| Markdownlint | `markdownlint --config .markdownlint.json '**/*.md'` | BLOCKED | configured in CI and pre-commit | Package unavailable locally and external package download was unavailable |
| Terraform formatting | `terraform fmt -check -recursive` | BLOCKED | workflow pins Terraform 1.15.8 and verifies its SHA-256 | Terraform CLI unavailable locally |
| Terraform init and validate | `make validate` | BLOCKED | backend-free validation script and CI job created | Provider-aware validation requires Terraform and provider downloads |
| TFLint | `tflint --init && tflint --recursive` | BLOCKED | TFLint 0.63.1 and AzureRM ruleset configured in CI | CLI/plugin unavailable locally |
| Azure backend/landing-zone plan | `make plan-lab` | BLOCKED | exact commands and input examples created | Requires subscription, backend, RBAC, network access, and authentication |
| Azure apply | `make deploy-lab` | BLOCKED | exact-plan checksum and confirmation controls created | No plan or Azure credentials |
| AKS/Jupyter smoke test | `make smoke-test` | NOT RUN | scripts and evidence procedure created | No deployment claimed |
| Destroy and residual-resource verification | `make destroy-lab` | NOT RUN | destroy plan/apply and independent Azure inventory checks created | No deployment existed to destroy |

## Interpretation

A passing HCL parser and Checkov run do not prove that the AzureRM provider
accepts every argument or that Azure will provision the design. Public release
remains gated on provider-aware CI, a reviewed Azure plan, a complete
foundation apply/smoke/destroy lifecycle, and sanitized evidence.

The Checkov result means that every non-exempt enabled check completed without
a finding. It is not evidence that an Azure environment is secure. Accepted
lab exceptions are listed in
[`docs/security/scan-exceptions.md`](../security/scan-exceptions.md).
