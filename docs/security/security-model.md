# Security model

| Threat | Control |
| --- | --- |
| Long-lived CI credential theft | GitHub OIDC; no client secret |
| Storage key leakage | shared keys disabled; Azure RBAC backend |
| State exposure | private container, restricted network rules, short-lived local files |
| Kubeconfig leak/global overwrite | ignored isolated file under `artifacts/` |
| AKS local bypass | local accounts disabled; Microsoft Entra Azure RBAC |
| Unrestricted API | required CIDR allowlist or private mode |
| Copied-source authorship confusion | upstream repositories removed/attributed |
| Unsafe repository artifact | publication-policy and secret-pattern scans |
| Unreviewed infrastructure change | reviewed plan, protected environment, exact-plan apply |
| Persistent cost | opt-in services, caps, destroy and inventory checks |

Residual risks include Terraform state metadata, privileged role-assignment operations, GitHub-hosted runner network access, dummy Jupyter authentication, and the limits of static scanning.

## Self-hosted deployment runner

The Azure plan/apply/destroy workflows run only on a dedicated runner labelled
`azure-lab`. Do not register that runner for untrusted pull-request jobs. Prefer
an ephemeral VM or containerized runner, restrict its outbound IP in the state
firewall, keep no reusable Azure secret on disk, and destroy or reimage it after
sensitive testing. Workflows remove local plan material and Terraform working
directories with `if: always()` cleanup steps.
