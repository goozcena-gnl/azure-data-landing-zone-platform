# Agent Instructions

## Repository purpose

This repository is an evidence-backed Terraform Azure landing-zone lab. Preserve the explicit boundary between the empirically validated foundation lifecycle and components that are implemented or prepared but not runtime-validated.

## Sources of truth

- `docs/architecture/overview.md` describes architecture.
- `docs/validation/test-matrix.md` records validation status.
- `docs/validation/2026-07-18-foundation-lifecycle.md` records the retained deploy/destroy evidence.
- `docs/known-limitations.md` defines current limitations.
- `SECURITY.md` and `docs/security/scan-exceptions.md` define security expectations and reviewed exceptions.

## Mandatory static validation

For Terraform, workflow, security, or repository changes, run the applicable gates:

```bash
terraform fmt -check -recursive
bash ./scripts/lint.sh
bash ./scripts/terraform-validate.sh
make terraform-test
tflint --init
tflint --recursive
bash ./scripts/security-scan.sh
python3 scripts/secret-scan.py --root .
python3 scripts/check-doc-links.py
bash terraform_backend_setup/tests/regression.sh
git diff --check
```

Do not report a check as passed unless it was executed successfully.

## Trust and execution boundaries

- Static validation is not Azure runtime validation.
- Do not run `terraform apply`, `terraform destroy`, Azure mutations, AKS changes, or OIDC/environment changes without explicit human authorization.
- Preserve exact-plan review and any existing PLAN -> APPLY integrity controls.
- Never expose Terraform plans, state, credentials, kubeconfigs, access tokens, or provider output containing secrets.
- Do not replace Entra/OIDC-based design with long-lived reusable credentials.
- Do not weaken policy, security scanning, backend checks, or protected-environment assumptions to make CI green.

## Evidence rules

Use the repository status vocabulary faithfully: `PASS`, `FAIL`, `BLOCKED`, `NOT RUN`, and `NOT APPLICABLE`. Never convert implemented or statically validated code into a runtime claim.

## Pull request discipline

- Keep diffs minimal and scoped.
- Document whether Azure authentication was used.
- Document whether plan/apply/destroy or AKS/JupyterHub runtime checks were executed.
- Do not merge or release on behalf of the user.