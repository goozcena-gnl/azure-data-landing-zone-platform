# Changelog

## [Unreleased]

### Added

- Sanitized evidence for the empirically validated 34-resource foundation plan/apply/no-drift/smoke/destroy/backend-cleanup lifecycle.
- Fixture-only backend helper regression suite covering scoped/inherited RBAC, JSON errors, multiline properties, null values, hardening, and idempotence.
- Read-only AKS provider/version/SKU/quota/admin-group/OIDC preflight with optional redacted JSON output.
- Read-only Entra security-group discovery and stable object-ID validation.
- Fail-closed, explicitly confirmed backend resource-group deletion helper.
- GitHub OIDC, protected-environment, repository-setting, Entra preparation, and known-limitations guides.
- Secure remote-state bootstrap with Microsoft Entra authorization.
- Modular foundation, governance, and optional AKS components.
- GitHub validation, dependency review, OIDC plan/apply, and destroy workflows.
- Preserved Azure DevOps static validation pipeline.
- Repository, secret-pattern, IaC, shell, YAML, and documentation checks.
- Deployment, validation, destruction, security, cost, architecture, and migration runbooks.

### Changed

- Replaced Azure CLI 2.88-incompatible scoped RBAC listing with object-ID, role, and scope-aware structured filtering that intentionally includes inherited assignments.
- Replaced multiline Storage TSV parsing with fail-closed `jq` normalization that preserves `false` and `null` and distinguishes CLI or schema errors.
- Added Terraform validation for region, VM SKU, node-count limits, Entra group UUIDs, AKS admin-group presence, and Jupyter's dependency on AKS.
- Added same-commit verification to the one-day reviewed-plan artifact and exposed the state key as a protected environment variable.
- Updated status language to claim only the empirically validated foundation lifecycle; AKS, Jupyter, OIDC, and GitHub deployment remain unvalidated.
- Documented that no branch-protection rule was changed because the current organization plan would not enforce it.
- Reframed the project as a disposable portfolio lab rather than an unqualified production platform.
- Replaced storage keys and reusable CI secrets with Azure RBAC and OIDC.
- Separated AKS provisioning from Kubernetes/Helm workload installation.
- Reduced AKS from the original expensive multi-node profile to an opt-in single-node default.
- Consolidated overlapping report material into scoped documentation.

### Removed or externalized

- Private keys, kubeconfig, secrets, passwords, real variables, state, plans, and credential-bearing archives.
- `.terraform`, provider binaries, downloaded CLI binaries, caches, and `Zone.Identifier` files.
- Nested Git metadata and complete copies of Jupyter Docker Stacks, Inframap, and Azure Naming Tool.
- Incomplete/costly Databricks, Synapse, SQL, ingestion, storage, and VM prototypes from the active root.
- Raw scanner output and unredacted screenshots.
