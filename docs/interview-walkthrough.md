# Azure platform interview walkthrough

Use this route to explain the repository from problem definition through
evidence, trade-offs, and next steps. It summarizes existing implementation and
records; it does not add a runtime-validation claim.

## 1. Problem and platform boundary

The project provides a reproducible Terraform lab for an Azure landing-zone
foundation: separately managed state, governance, networking, security
controls, observability, and disciplined teardown. It is intentionally smaller
than an enterprise Azure landing zone and does not claim a production support
baseline. The [architecture overview](architecture/overview.md) and
[publishable-scope decision](decisions/0001-publishable-scope.md) define that
boundary.

The empirical claim is narrower than the implemented tree: the disposable
foundation lifecycle was exercised end to end. Optional Key Vault, AKS,
JupyterHub, GitHub OIDC, protected environments, and GitHub-controlled
deployment were not runtime validated.

## 2. Why the foundation was validated first

The foundation isolates the controls that every later platform component
depends on: remote state, resource groups, networking, policy, logging, tags,
and cost limits. Validating it with `enable_aks=false` reduced billable scope and
separated foundation correctness from regional AKS SKU, quota, and identity
prerequisites. The [deployment runbook](lab/deployment.md) therefore requires a
foundation-first plan before any optional AKS decision.

## 3. Terraform roots, modules, and state bootstrap

- `infra/bootstrap` creates the dedicated Azure Storage backend. Shared-key
  access is disabled; operators use Microsoft Entra data-plane authorization.
- `infra/landing-zone` is the deployable root and composes the retained
  platform modules.
- `infra/modules/foundation` provides resource groups, the VNet and subnets,
  NSGs, Log Analytics, and optional private Key Vault plumbing.
- `infra/modules/governance` implements the retained location and required-tag
  policy examples.
- `infra/modules/aks` implements the optional cluster boundary.

The backend is managed separately so landing-zone destruction cannot remove
the state needed to complete that destruction. The
[authentication and state ADR](decisions/0002-authentication-and-state.md) and
[security model](security/security-model.md) explain the credential boundary.

## 4. Governance, networking, identity, and security decisions

The foundation uses a VNet with separate AKS, private-endpoint, and shared
services subnets; NSGs; a capped Log Analytics workspace; and custom policies
for allowed locations and required tags. This demonstrates policy-as-code but
does not substitute for management-group governance or an enterprise policy
initiative.

Security choices include Entra-authorized state access, disabled AKS local
accounts, Microsoft Entra Azure RBAC, no kubeconfig Terraform output, explicit
API CIDRs or private mode, short-lived plan material, and OIDC-ready workflows
instead of a reusable Azure client secret. Accepted compromises and their
production positions are recorded in the
[security exception register](security/scan-exceptions.md).

## 5. Exact validated lifecycle

The dated [foundation lifecycle record](validation/2026-07-18-foundation-lifecycle.md)
supports this exact sequence:

1. Review a saved `34 add / 0 change / 0 destroy` plan.
2. Apply that exact saved plan: `34 added / 0 changed / 0 destroyed`.
3. Run foundation smoke tests and inventory/tag checks.
4. Run a fresh refresh plan and confirm no drift.
5. Review a delete-only `0 add / 0 change / 34 destroy` plan.
6. Apply that exact destroy plan: `34 destroyed`.
7. Confirm empty Terraform state and outputs.
8. Perform residual Azure inventory checks.
9. Delete the separately managed backend and verify its absence.

The [test matrix](validation/test-matrix.md) distinguishes this runtime evidence
from static checks and unexecuted optional paths.

## 6. What remains outside empirical validation

- AKS provisioning was not run because the assessed SKU, regional quota, and
  eligible Entra administrator-group prerequisites were not satisfied.
- Entra-integrated AKS administration was not exercised because no cluster or
  eligible configured group existed.
- JupyterHub was not installed or smoke-tested because AKS was absent.
- GitHub OIDC and protected-environment behavior were not exercised because the
  federated credentials and environments were not configured.
- GitHub-controlled plan, apply, and destroy are prepared but were not run.
- Optional private Key Vault was implemented but disabled in the validated run.

These are `NOT RUN` boundaries, not failed runtime demonstrations. The current
[known limitations](known-limitations.md) remain authoritative.

## 7. Teardown and residual-resource discipline

Teardown is part of the validation claim, not an afterthought. The operator
reviews and applies an exact delete-only plan, proves state and outputs are
empty, checks Azure inventories for matching groups, policies, disks, public
IPs, load balancers, and interfaces, and only then considers backend deletion.

The backend helper requires the expected subscription context, purpose tag,
exact storage/container/blob inventory, empty state, and typed confirmation.
The [destroy runbook](lab/destroy.md) documents the complete fail-closed route.

## 8. Security and cost trade-offs

The disposable lab keeps AKS and Key Vault disabled by default, caps Log
Analytics ingestion, uses short retention, and requires prompt teardown. These
choices reduce cost but do not make Azure resources free; nodes, disks, load
balancers, logging, networking, and egress can remain billable.

Reproducibility from a workstation or hosted runner also leads to explicit lab
exceptions: allowlisted public access to state rather than a private endpoint,
LRS rather than zone/geo redundancy, platform-managed rather than
customer-managed encryption, and a one-node Free-tier AKS design if AKS is
later enabled. The [cost-control runbook](lab/cost-control.md) and
[exception register](security/scan-exceptions.md) keep those trade-offs visible.

## 9. What changes for production

A production implementation would derive controls from organizational threat,
recovery, compliance, and availability requirements. Likely changes include
management groups and policy initiatives, centralized networking and private
DNS, private state access from controlled runners, state diagnostics and an
approved redundancy/encryption strategy, production identity and RBAC,
Defender and centralized monitoring, separated AKS system/user pools, a paid
tier where an SLA is required, tested recovery, and independent approvals.

JupyterHub would require real authentication, ingress/TLS, persistence,
network policy, workload isolation, and an operating model. None of these are
claims about the current repository runtime.

## 10. Lessons learned and next steps

The main lesson is to treat evidence as a lifecycle: review the exact plan,
apply that plan, test convergence, verify no drift, destroy from a reviewed
plan, and prove the absence of residual resources. Separating state bootstrap,
the foundation, optional AKS, and post-cluster Helm workloads keeps failure and
credential boundaries understandable.

Next steps remain gated rather than assumed: repeat current subscription and
SKU preflight, configure an eligible Entra group, decide the explicit AKS cost
and network boundary, configure and validate GitHub OIDC/environments, then
consider JupyterHub only after the cluster itself has empirical evidence. See
the [AKS/workload separation ADR](decisions/0003-separate-aks-workloads.md) and
[repository roadmap](../README.md#roadmap).
