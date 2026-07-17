# ADR 0002: Use Azure RBAC state access and GitHub OIDC

- Status: Accepted
- Date: 2026-07-14

The original bootstrap wrote storage account keys to generated files and the archive contained reusable Azure credentials. Shared keys are now disabled; local state access uses Azure CLI identity and CI uses workload identity federation. Account-specific values live in local ignored files or protected GitHub variables/environments.
