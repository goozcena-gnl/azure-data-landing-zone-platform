# Changelog

## [Unreleased]

### Added

- Secure remote-state bootstrap with Microsoft Entra authorization.
- Modular foundation, governance, and optional AKS components.
- GitHub validation, dependency review, OIDC plan/apply, and destroy workflows.
- Preserved Azure DevOps static validation pipeline.
- Repository, secret-pattern, IaC, shell, YAML, and documentation checks.
- Deployment, validation, destruction, security, cost, architecture, and migration runbooks.

### Changed

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
