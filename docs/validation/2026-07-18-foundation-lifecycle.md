# Foundation lifecycle evidence — 2026-07-18

## Evidence scope

This sanitized record covers one disposable, foundation-only Azure laboratory
lifecycle. It was reconciled with the final local workspace after the raw saved
plans, temporary provider directories, backend configuration, and Azure
resources were intentionally removed.

| Field | Value |
| --- | --- |
| Date | 2026-07-18 |
| Environment | Personal, disposable Azure laboratory |
| Terraform | 1.15.8 |
| Azure CLI | 2.88.0 |
| Subscription | `<subscription-id-redacted>` |
| Tenant | `<tenant-id-redacted>` |
| Public client address | `<public-ip-redacted>` |
| Backend account | `<storage-account-name-redacted>` |
| Deployment root | `infra/landing-zone` |

This document contains summaries and cryptographic plan hashes, not raw plan,
state, backend, or CLI-debug content.

## Configuration exercised

Enabled:

- foundation resource groups;
- virtual network, subnets, and network security groups;
- Log Analytics and diagnostic configuration;
- custom location and required-tag policies;
- common tags and cost controls.

Disabled:

- AKS;
- JupyterHub;
- private Key Vault.

GitHub Actions OIDC and GitHub protected environments were not used for this
execution. The lifecycle ran from the approved local operator context.

## Deployment

The reviewed saved plan was exactly:

```text
34 to add
0 to change
0 to destroy
```

Saved plan SHA-256:

```text
d3d189b7ae1e3accab64821e0b61208fdafb8060484b93d689a0e5efd8ca064a
```

The exact saved plan was applied:

```text
34 added
0 changed
0 destroyed
```

Formatting and provider-aware Terraform validation passed before the plan.

## Post-deployment validation

A fresh refresh plan reported no changes. Foundation smoke tests passed, and
the expected five top-level tagged Azure resources were present. The evidence
was reduced to counts and outcomes; resource IDs and names are not published.

This proves the disposable foundation configuration converged in the tested
subscription and region on the recorded date. It does not prove that every
optional component or every Azure subscription will behave identically.

## Destruction

The reviewed saved destroy plan was delete-only:

```text
0 to add
0 to change
34 to destroy
```

Destroy plan SHA-256:

```text
7219d11e5cff2e1f0a9ea0155b6f66efad4bde2f3f58f73e3b102c53e6414e05
```

The exact destroy plan was applied:

```text
0 added
0 changed
34 destroyed
```

After destruction, the remote state contained zero managed resources and zero
outputs.

## Residual-resource and backend verification

Read-only post-destroy inventory found:

- no matching foundation resource groups;
- no tagged landing-zone resources;
- no matching custom policy definitions or assignments;
- no matching managed disks, public IP addresses, load balancers, or network
  interfaces.

The separately managed backend container, state blob, storage account, and
dedicated resource group were then deleted. A final inventory found no
remaining backend or landing-zone resources. Raw plans and temporary local
Terraform working directories were deleted.

## Limitations

- AKS was not deployed.
- Entra-integrated AKS administration was not exercised.
- JupyterHub was not installed or smoke-tested.
- GitHub OIDC login was not exercised.
- GitHub Environment approvals were not configured or exercised.
- GitHub-controlled plan/apply/destroy was not empirically validated.
- The raw binary plans are intentionally unavailable; their hashes preserve
  identity but cannot reconstruct their content.

The precise claim supported by this record is: **the disposable Azure
foundation lifecycle was empirically validated end to end, including no drift,
smoke tests, destruction, residual checks, and backend deletion.**
