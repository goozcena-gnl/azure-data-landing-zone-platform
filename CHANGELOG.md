# Changelog

## [Unreleased]

No changes are currently documented outside the prepared v0.1.0 scope.

## [0.1.0] - prepared for release

This section records the release candidate scope. The v0.1.0 artifacts, tag,
and GitHub Release have not yet been created or published.

### Added

- Sanitized evidence for the empirically validated 34-resource foundation plan/apply/no-drift/smoke/destroy/backend-cleanup lifecycle.
- Fixture-only backend helper regression suite covering scoped/inherited RBAC, JSON errors, multiline properties, null values, hardening, and idempotence.
- Read-only AKS provider/version/SKU/quota/admin-group/OIDC preflight with optional redacted JSON output.
- Read-only Entra security-group discovery and stable object-ID validation.
- Fail-closed, explicitly confirmed backend resource-group deletion helper.
- GitHub OIDC, protected-environment, repository-setting, Entra preparation, and known-limitations guides.
- A post-publication repository audit covering all branches and reachable history, pull-request text, available Actions logs, artifacts, and protected historical SHAs.
- Secure remote-state bootstrap with Microsoft Entra authorization.
- Modular foundation, governance, and optional AKS components.
- GitHub validation, dependency review, OIDC plan/apply, and destroy workflows.
- Preserved Azure DevOps static validation pipeline.
- Repository, secret-pattern, IaC, shell, YAML, and documentation checks.
- Deployment, validation, destruction, security, cost, architecture, and migration runbooks.

### Changed

- Enabled and API-verified public-repository secret-scanning user alerts, push
  protection, and private vulnerability reporting; recorded zero secret and
  Dependabot alerts at verification time.
- Documented that advanced validity, metadata, non-provider, and custom secret
  patterns remain unavailable without organization and/or paid Secret
  Protection entitlement, while CodeQL remains deferred.
- Replaced Azure CLI 2.88-incompatible scoped RBAC listing with object-ID, role, and scope-aware structured filtering that intentionally includes inherited assignments.
- Recorded the successful post-publication Dependency Review rerun and the clean public/private repository boundary.
- Replaced multiline Storage TSV parsing with fail-closed `jq` normalization that preserves `false` and `null` and distinguishes CLI or schema errors.
- Added Terraform validation for region, VM SKU, node-count limits, Entra group UUIDs, AKS admin-group presence, and Jupyter's dependency on AKS.
- Added same-commit verification to the one-day reviewed-plan artifact and exposed the state key as a protected environment variable.
- Updated status language to claim only the empirically validated foundation lifecycle; AKS, Jupyter, OIDC, and GitHub deployment remain unvalidated.
- Activated and API-verified the `Protect main` ruleset with the `repository`,
  `terraform`, and `review` GitHub Actions contexts, strict branch currency,
  linear history, conversation resolution, deletion protection, and
  non-fast-forward protection.
- Rebase-merged pull request #5 after its reviewed head, required checks,
  conversation state, and active ruleset were verified; the release branch was
  then deleted.
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

### Explicit exclusions

- AKS and JupyterHub were not deployed.
- GitHub-to-Azure OIDC and GitHub-controlled Azure deployment were not
  empirically validated.
- The project is a disposable professional laboratory, not a production
  reference implementation.
