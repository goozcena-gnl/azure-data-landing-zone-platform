# Test matrix

| Layer | Test | Command | Success evidence |
| --- | --- | --- | --- |
| A | Repository policy | `python3 tests/repository_policy.py` | no forbidden files/binaries/key markers |
| A | Secret pattern scan | `python3 scripts/secret-scan.py --root .` | zero findings |
| B | HCL parsing | local parser utility | every `.tf` parses |
| B | Terraform format | `terraform fmt -check -recursive` | exit 0 |
| B | Terraform validate | `make validate` | backend-free init/validate for both roots |
| B | TFLint | `tflint --init && tflint --recursive` | no blocking findings |
| B | Checkov | `make security` | no unaccepted failure |
| B | Shell/YAML/Markdown | `make lint && make docs-check` | exit 0 |
| B | Dependency Review | GitHub Actions `review` job | public dependency diff passes |
| C | Azure plan | `make plan-lab` | reviewed plan; no unexpected changes |
| D | Foundation apply | `make deploy-lab` | Terraform/Azure success |
| D | Optional AKS | reviewed plan/apply | expected identity/network/security settings |
| E | Smoke tests | `make smoke-test` | expected Azure inventory; nodes/workloads healthy |
| E | JupyterHub | `bash ./scripts/deploy-jupyter.sh` | Helm healthy; local endpoint responds |
| E | Logging | documented KQL | recent expected records |
| F | Destroy | `make destroy-lab` | apply succeeds; no unexplained chargeable remnants |

## Empirical status on 2026-07-18

| Capability | Status | Evidence boundary |
| --- | --- | --- |
| Repository policy and sanitization | PASS | Local policy and secret-pattern checks |
| Public history and publication surface | PASS | Six branches, 17 reachable commits, PRs #1–#5, and available Actions logs |
| Dependency Review | PASS | Public pull-request rerun, attempt 2 |
| Terraform formatting and provider validation | PASS | Both Terraform roots |
| Foundation saved plan | PASS | `34 add / 0 change / 0 destroy`; hash retained |
| Foundation exact-plan apply | PASS | `34 added / 0 changed / 0 destroyed` |
| Foundation no-drift refresh | PASS | No changes |
| Foundation smoke tests | PASS | Expected foundation inventory and tags |
| Foundation saved destroy plan | PASS | `0 add / 0 change / 34 destroy`; hash retained |
| Foundation exact destruction | PASS | `34 destroyed`; empty remote state |
| Residual inventory and backend deletion | PASS | No matching landing-zone or backend resources |
| Backend helper regression coverage | PASS | Fixture-only structured RBAC and Storage tests |
| AKS provisioning | NOT RUN | SKU/quota/admin-group blockers; no plan generated |
| Entra-integrated AKS administration | NOT RUN | No cluster or eligible configured group |
| JupyterHub installation/smoke test | NOT RUN | AKS prerequisite absent |
| GitHub OIDC | NOT RUN | Federated credentials absent |
| GitHub Environment approvals | NOT RUN | Environments absent |
| GitHub deployment lifecycle | NOT RUN | Workflows prepared but not empirically exercised |
