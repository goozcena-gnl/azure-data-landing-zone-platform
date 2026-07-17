# Architecture overview

The repository implements a disposable Azure lab with separately managed state. It is intentionally smaller than an enterprise-scale Azure landing zone.

## State bootstrap

`infra/bootstrap` creates a state resource group, hardened StorageV2 account, private container, blob versioning and retention, restricted network rules, and optional `Storage Blob Data Contributor` assignment. Shared access keys are disabled and backend configuration contains no credential.

## Foundation

`infra/modules/foundation` creates network, management, and platform resource groups; a VNet and three subnets; NSGs; a capped Log Analytics workspace; and an optional private Key Vault with DNS/private endpoint.

## Governance

`infra/modules/governance` demonstrates policy-as-code through allowed-location enforcement and required-tag auditing. It is not a substitute for enterprise management-group governance.

## AKS

The optional module uses a user-assigned managed identity, Microsoft Entra Azure RBAC, disabled local accounts, OIDC issuer, Workload Identity, Azure CNI Overlay/Cilium, authorized API CIDRs or private mode, optional Container Insights/Azure Policy, and control-plane diagnostics.

Kubeconfig is deliberately absent from Terraform outputs.

## Workloads

Helm workloads are installed after AKS is healthy. This avoids a fragile same-apply dependency between cluster creation and Kubernetes/Helm providers. JupyterHub is a pinned external chart with a small local overlay.
