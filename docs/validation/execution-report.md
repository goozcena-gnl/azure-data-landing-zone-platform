# Validation execution report

## Current release validation

- Date: 2026-07-20
- Final main: `f357c7db3652c0d645eff575153511186912209c`
- Pull request #5: rebase-merged
- Protect main ruleset: active; merge rule suite `3388422621` passed
- Environment: local WSL/Linux repository plus approved read-only Azure
  preflight
- Terraform: 1.15.8
- Azure CLI: 2.88.0
- Python: 3.12.3
- Bash: 5.2.21
- jq: 1.7
- TFLint: 0.63.1; bundled Terraform rules 0.15.0; AzureRM rules 0.28.0
- Checkov: 3.3.8
- ShellCheck: 0.11.0
- Yamllint: 1.37.1
- Markdownlint CLI: 0.49.0
- Bats Core: 1.12.0
- Git: 2.43.0
- Gitleaks: 8.30.1

### Results

| Test | Command | Status | Evidence | Limitation |
| --- | --- | --- | --- | --- |
| Repository policy | `python3 tests/repository_policy.py` | PASS | no forbidden files, binaries, nested Git metadata, or mutable Action refs | Static policy |
| Secret-pattern scan | `python3 scripts/secret-scan.py --root .` | PASS | zero findings | Heuristic; not a substitute for history review |
| Terraform format | `terraform fmt -check -recursive` | PASS | exit 0 after mechanical format | HCL style only |
| Terraform init/validate | `make validate` | PASS | bootstrap and landing-zone initialized backend-free; both valid | Cached locked providers |
| Terraform input tests | `make terraform-test` | PASS | 8 provider-mocked plans passed | No Azure API call |
| TFLint | `tflint --recursive` | PASS | zero findings | Static rules |
| Checkov | `make security` with 3.3.8 | PASS | 44 passed, 0 failed | Documented lab exceptions remain |
| ShellCheck | `shellcheck -x` over retained shell scripts | PASS | zero findings | Static shell analysis |
| Yamllint | `yamllint -c .yamllint.yml` | PASS | all workflow/config YAML passed | Service semantics assessed separately |
| Markdownlint | `markdownlint-cli` 0.49.0 over exact repository Markdown list | PASS | zero findings | Local files only |
| Backend standalone regressions | `make backend-test` | PASS | 24 passed, 0 failed | Fixture-only Azure CLI |
| Backend Bats suite | `bats terraform_backend_setup/tests/terraform_setup.bats` | PASS | 6 passed, 0 failed | Azure CLI mocked |
| Documentation links | `make docs-check` | PASS | no broken local targets | External links not crawled |
| Make command surface | `make help` | PASS | all documented targets resolve | Help only |
| Git whitespace | `git diff --check` | PASS | no whitespace errors | Uncommitted review surface |
| Public history and surface audit | Gitleaks plus deterministic publication checks | PASS | current five-branch inventory, reachable history, PRs #1–#5, available Actions logs, and protected historical SHAs clean | One startup-failure run had no downloadable log |
| Dependency Review | public pull-request rerun | PASS | `review` attempt 2 completed successfully | Dependency diff only |
| Foundation plan/apply | sanitized lifecycle record | PASS | exact 34-resource plan and apply | Foundation only |
| Foundation no drift/smoke | sanitized lifecycle record | PASS | no changes; expected inventory | Foundation only |
| Foundation destroy/cleanup | sanitized lifecycle record | PASS | 34 destroyed; state/backend/residual inventory empty | Historical empirical run |
| AKS read-only preflight | `scripts/aks-preflight.sh` | BLOCKED | providers/versions/quota pass; configured SKU restricted; admin group absent | No fallback selected |
| AKS deployment | not run | NOT RUN | no saved AKS plan | Requires explicit approval after blockers |
| JupyterHub deployment | not run | NOT RUN | AKS prerequisite absent | No endpoint test |
| GitHub OIDC deployment | not run | NOT RUN | credentials and variables absent | Manual administration required |
| GitHub Environment gates | not run | NOT RUN | environments absent | Current plan enforcement must be checked |
| Pre-merge packaging implementation | `make package-release` | PASS | tracked-file ZIP, manifest, checksums, and clean extraction passed before the PR #5 merge | Not an official post-merge v0.1.0 candidate |
| Pre-merge extracted archive | Bats 1.12.0 and Markdownlint 0.49.0 | PASS | 6 Bats tests and all Markdown files passed in the earlier extracted copy | Must be rerun after the corrective merge |
| Public security settings | GitHub REST API read-back | PASS | secret scanning user alerts, push protection, and private vulnerability reporting enabled; Dependabot unchanged and enabled | Advanced paid or organization-only protections excluded |
| Public security alerts | GitHub REST API sanitized inventory | PASS | zero secret-scanning and zero Dependabot alerts on 2026-07-20 | Point-in-time observation; scan-history API requires Advanced Security |
| Code scanning | read-only capability assessment | NOT APPLICABLE | CodeQL default setup is not configured | CodeQL deliberately deferred |
| PR #5 rebase merge | REST, GraphQL, CLI, and linear-history verification | PASS | reviewed head rebase-merged to final main `f357c7d`; release branch deleted | Rebased commit IDs differ from source IDs |
| Main ruleset | ruleset and effective-rule API read-back | PASS | `Protect main` ID `19208283` active; merge rule suite `3388422621` passed all five rules | Zero approving reviews in sole-maintainer baseline |
| Release documentation inspection | final-main stale-state audit | FAIL | five expected files plus `docs/github/repository-settings.md` contradicted the merged/protected state | Blocks official artifacts |
| Corrective documentation PR | `docs/v0.1.0-release-readiness` | NOT RUN | correction prepared; pull-request merge remains pending | Must merge before release validation restarts |
| Post-correction validation and packaging | not run | NOT RUN | requires the new exact main SHA after corrective merge | No official v0.1.0 artifacts exist |
| Annotated tag and GitHub Release | not run | NOT RUN | no v0.1.0 tag or release exists | Separate later authorization gates |

The full lifecycle evidence, including plan hashes and explicit exclusions, is
in [`2026-07-18-foundation-lifecycle.md`](2026-07-18-foundation-lifecycle.md).
Known limitations are in
[`../known-limitations.md`](../known-limitations.md).

### Interpretation

The backend defects are fixed and covered by both executable standalone tests
and the existing Bats framework. Terraform's provider-mocked tests prove that
invalid Jupyter/AKS, group-ID, node-count, VM-size, and location combinations
fail before an Azure plan.

The packaging implementation generates from committed `HEAD` only. Its
external `file-manifest.csv` records path, size, content SHA-256, and
publication category; `SHA256SUMS` verifies both the ZIP and manifest. The
earlier package validation predates the PR #5 merge and is not an official
v0.1.0 candidate. Complete validation, clean extraction, and independent
reproducibility testing must restart after the corrective documentation merge.

The read-only AKS preflight did not deploy anything. It confirmed that the
configured VM family quota could cover the requested two vCPUs, but the
selected `Standard_D2s_v5` SKU remained restricted for the subscription in
France Central. No security-enabled Entra administrator group was configured.
AKS therefore remains blocked and no alternate SKU or region was selected.

A passing static or mocked test is not empirical AKS, Jupyter, GitHub OIDC, or
GitHub Environment validation.

GitHub-native secret scanning and push protection now complement the
repository's deterministic scans and history audit. They do not replace
credential revocation or rotation when exposure is suspected. Advanced
validity, metadata, non-provider, and custom pattern features were unavailable
to the current user-owned repository without organization and/or paid Secret
Protection entitlement.

---

## Historical baseline (2026-07-14, superseded)

The section below is retained as provenance for the pre-Azure, pre-finalization
baseline. Its release-readiness conclusions are superseded by the current
report above.

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
