# Migration from the original archive

The publishable repository was rebuilt in a new directory; the source archive was treated as untrusted input.

Retained/refactored: Data Landing Zone purpose, modular Terraform, network/monitoring/governance, optional AKS/Jupyter, Azure DevOps validation concept, and learning narrative.

Removed: all secrets/private keys/kubeconfig/passwords/tokens/state/plans; `.terraform`, providers, CLI binaries, caches and ADS metadata; nested repos/upstream source; raw scans/screenshots; incomplete high-cost modules.

Externalized: Jupyter Docker Stacks as a pinned image, JupyterHub as a pinned chart/overlay, Azure Naming Tool as release/fork dependency, and Inframap as an installed documentation tool.

This is not an in-place state migration. Do not attach the new root to old state; use a fresh lab scope unless a separate import/migration plan is reviewed.
