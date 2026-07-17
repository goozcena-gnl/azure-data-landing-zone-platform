# Test matrix

| Layer | Test | Command | Success evidence |
|---|---|---|---|
| A | Repository policy | `python3 tests/repository_policy.py` | no forbidden files/binaries/key markers |
| A | Secret pattern scan | `python3 scripts/secret-scan.py --root .` | zero findings |
| B | HCL parsing | local parser utility | every `.tf` parses |
| B | Terraform format | `terraform fmt -check -recursive` | exit 0 |
| B | Terraform validate | `make validate` | backend-free init/validate for both roots |
| B | TFLint | `tflint --init && tflint --recursive` | no blocking findings |
| B | Checkov | `make security` | no unaccepted failure |
| B | Shell/YAML/Markdown | `make lint && make docs-check` | exit 0 |
| C | Azure plan | `make plan-lab` | reviewed plan; no unexpected changes |
| D | Foundation apply | `make deploy-lab` | Terraform/Azure success |
| D | Optional AKS | reviewed plan/apply | expected identity/network/security settings |
| E | Smoke tests | `make smoke-test` | expected Azure inventory; nodes/workloads healthy |
| E | JupyterHub | `bash ./scripts/deploy-jupyter.sh` | Helm healthy; local endpoint responds |
| E | Logging | documented KQL | recent expected records |
| F | Destroy | `make destroy-lab` | apply succeeds; no unexplained chargeable remnants |
