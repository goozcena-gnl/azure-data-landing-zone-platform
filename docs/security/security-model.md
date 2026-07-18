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
| Backend deletion of unrelated data | empty-state, purpose-tag, exact inventory, typed confirmation |
| Duplicate backend RBAC | object-ID scoped JSON lookup including inherited assignments |

Residual risks include Terraform state metadata, privileged role-assignment operations, GitHub-hosted runner network access, dummy Jupyter authentication, and the limits of static scanning.

The foundation lifecycle was empirically validated, but AKS, JupyterHub,
GitHub OIDC, and GitHub protected-environment behavior were not. Static
workflow review does not prove that GitHub or Azure will enforce an
unconfigured control. See [`../known-limitations.md`](../known-limitations.md).

## Self-hosted deployment runner

The Azure plan/apply/destroy workflows run only on a dedicated runner labelled
`azure-lab`. Do not register that runner for untrusted pull-request jobs. Prefer
an ephemeral VM or containerized runner, restrict its outbound IP in the state
firewall, keep no reusable Azure secret on disk, and destroy or reimage it after
sensitive testing. Workflows remove local plan material and Terraform working
directories with `if: always()` cleanup steps.

## Backend authentication and parsing

The backend helper uses Azure CLI Microsoft Entra login for data-plane calls;
shared-key access remains disabled. It never writes account keys.

Azure CLI responses that contain multiple security properties are normalized
from JSON with `jq`. Missing, empty, null, false, and command-error states are
handled separately. A malformed or incomplete response fails closed.

Scoped RBAC discovery uses principal object ID, role, explicit storage scope,
and intentional inherited-assignment inclusion. It does not combine the Azure
CLI 2.88-incompatible `--all` and `--scope` flags, and it refuses automatic
assignment when discovery cannot prove that no sufficient assignment exists.
