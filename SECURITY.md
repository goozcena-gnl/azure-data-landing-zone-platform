# Security policy

## Reporting

Do not open a public issue containing secrets, private keys, tenant/subscription identifiers, kubeconfig, state, plans, private URLs, or exploit details. Use GitHub private vulnerability reporting when enabled, or a private contact channel from the repository owner's profile.

## Credential incident rule

Any credential, token, kubeconfig, certificate private material, or private key stored in an archive or Git history is treated as compromised. Deletion is insufficient: revoke or rotate it, review relevant logs, invalidate cached credentials, and prevent recurrence.

## Forbidden repository content

- Terraform state/backups and binary or JSON plans;
- real `.tfvars`, backend files, cloud credentials, or `.env` files;
- private keys, kubeconfig, tokens, or password files;
- downloaded providers/CLIs and unexplained binaries;
- nested `.git` directories or full upstream repositories;
- unredacted screenshots, logs, or raw scanner dumps.

## Deployment security

GitHub deployment uses OIDC and protected environments. Long-lived Azure client secrets are not part of the design. Plan artifacts can still contain sensitive data; retain them briefly and restrict repository access.

Security exceptions require rationale, scope, compensating controls, and a review trigger in [`docs/security/scan-exceptions.md`](docs/security/scan-exceptions.md).
