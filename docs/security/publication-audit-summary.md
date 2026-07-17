# Publication audit summary

The inspected archive contained 2,051 regular files and approximately 573 MiB. It was not safe to publish.

Confirmed blockers included duplicated OpenSSH private keys, an AKS kubeconfig with private material/token, Azure/application secrets, hardcoded passwords, state/backups/plans, credential-bearing archives, nested Git repositories, full upstream source copies, provider/CLI binaries, hundreds of `Zone.Identifier` files, caches, raw scanner reports, and unredacted screenshots.

Values are not reproduced. Any real credential stored in the archive must be considered compromised and rotated/revoked. The public tree was reconstructed rather than copied wholesale. The detailed forensic inventory remains an offline audit artifact.
