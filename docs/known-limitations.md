# Known limitations

## Empirical scope

The disposable Azure foundation lifecycle is empirically validated. AKS,
JupyterHub, GitHub OIDC, protected GitHub Environments, and the GitHub-driven
deployment lifecycle are implemented or prepared but have not been exercised
against the real services.

The project is a laboratory and portfolio reference, not an enterprise landing
zone or production support commitment.

## AKS capacity and identity

The last read-only assessment in France Central found the configured
`Standard_D2s_v5` SKU unavailable to the selected subscription. The only
unrestricted alternatives returned at that time were unsuitable large
M-family sizes, while the applicable regional quota was four vCPUs. No eligible
security-enabled Entra administrator group was configured.

Azure availability and quota change over time. No fallback SKU or region is
hardcoded. Run `scripts/aks-preflight.sh` and make an explicit cost, region,
quota, and identity decision before generating any AKS plan.

Private-cluster connectivity and DNS are not a complete turnkey design in this
personal-lab baseline. The public-cluster option requires explicit authorized
CIDRs.

## JupyterHub

JupyterHub remains a post-AKS Helm phase. It uses laboratory-only dummy
authentication and a `ClusterIP` service. It must not be exposed to untrusted
networks. The overlay has not been installed on a real cluster in this project.

## Backend lifecycle

The validated backend was intentionally deleted after cleanup. Every new live
run must bootstrap a dedicated backend before Terraform initialization.

The deletion helper refuses to remove a resource group unless state is empty,
the `purpose=terraform-state` tag is present, and the exact storage,
container, and blob inventory contains no unrelated active object. Azure
soft-delete retention is still a service-level behavior until the storage
account itself is deleted.

## GitHub controls

The workflows are prepared for OIDC and protected environments, but the
repository currently has no configured OIDC federated credentials, deployment
environments, Actions variables, or empirically tested GitHub deployment run.

The prior repository assessment found that branch-protection enforcement would
not be available under the current organization plan. No rule was created or
modified. Reassess plan and repository visibility before relying on branch
protection as a security boundary.

Deployment uses a dedicated self-hosted runner label. Operating, patching,
isolating, and reimaging that runner remain operator responsibilities.

## Governance and security

The policy set is intentionally small and demonstrates custom policy
definitions and resource-group assignments. It is not a replacement for Azure
Landing Zones policy initiatives, management groups, centralized networking,
Defender for Cloud, or an organizational identity model.

Static analysis, secret-pattern scans, and a clean repository policy reduce
risk but do not prove the absence of all defects or secrets. Terraform state
can contain metadata and must remain access-controlled.

## Cost

AKS nodes, disks, load balancers, logging, egress, and optional services are
billable. The defaults keep AKS, Jupyter intent, and Key Vault disabled, but an
operator must review every plan and current Azure pricing. No script silently
selects a different region or VM size.
