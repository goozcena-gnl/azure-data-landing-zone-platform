# File action register

The source archive was handled as untrusted input and rebuilt into a separate
working directory. No secret-bearing file was copied and edited in place.

## Retained and refactored

- Azure Data Landing Zone learning objective and architecture narrative;
- Terraform module concept for foundations, governance, and AKS;
- Azure DevOps validation concept;
- AKS and Jupyter demonstration intent;
- useful lessons from `rapport.md` and `dlz_report.md`, consolidated into the
  root README and scoped documentation.

## Sanitized or regenerated

- Terraform roots, provider constraints, variables, outputs, and modules;
- remote-state bootstrap without storage keys;
- example variables containing only documentation placeholders;
- OIDC-based GitHub workflows with immutable action pins;
- scripts, test matrix, evidence model, and security documentation;
- scanner evidence reduced to human-readable policy and execution summaries.

## Removed

- private SSH keys, kubeconfig, client certificates, tokens, client secrets,
  passwords, real `.tfvars`, and account-specific authentication files;
- Terraform state, backups, plans, plan JSON, and state-bearing archives;
- `.terraform`, provider executables, `kubectl`, Inframap binaries, build
  output, Python/.NET caches, and Windows `Zone.Identifier` metadata;
- nested `.git` directories, redundant archives, raw scanner dumps, and
  screenshots exposing personal or Azure DevOps context;
- incomplete or costly active modules for Databricks, Synapse, SQL, ingestion,
  generic storage, and virtual machines.

## Externalized

- Jupyter Docker Stacks and JupyterHub upstream source;
- Azure Naming Tool upstream application;
- Inframap source and binary.

## State compatibility

This is not an in-place refactor of the original Terraform state. The new
resource addresses and architecture must use a fresh disposable lab or a
separately reviewed import/migration plan. Never point this root at archived
state files.
