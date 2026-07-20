# Publication audit summary

## Current reachable Git repository

After public visibility, the clean repository was freshly cloned and audited
across `main`, the release branch, four Dependabot branches, every reachable
commit, tree, and blob, and all tags. The audited history contained only the
expected migration and documentation commits across six current branch trees,
with no tags or releases.

Gitleaks 8.30.1 scanned the complete reachable history and every current branch
tree with full redaction and reported zero leaks. Repository policy,
deterministic secret scanning, and publication-tree checks also found no real:

- Azure client secret, storage key, SAS token, password, or private key;
- Terraform state, saved plan, backend configuration, credential `.env`, or
  variable file;
- kubeconfig, provider or CLI binary, nested repository, cache, archive, or
  `Zone.Identifier` file;
- personal local path, internal school or organization reference, or public IP
  address.

GUID-bearing content is limited to documented placeholders, fixture identifiers,
and public Azure role-definition identifiers. Assignment-like content is
limited to scanner rules and an environment-variable placeholder in the
laboratory Jupyter configuration. Email-like content in reachable blobs is
limited to generic examples and approved GitHub-managed no-reply identities.
No matched value is reproduced here.

All author and committer identities use approved GitHub no-reply or
GitHub-managed identities. Thirty-two protected historical commit identifiers
were queried through the clean repository API and none was retrievable.

## GitHub publication surface

Pull requests #1 through #5, their comments, reviews, and available timeline
data were inspected. No personal email, developer-local path, concrete
account-specific Azure identifier, credential, or private-key material was
found.

The public repository had 14 Actions runs at audit time. Logs were available
for 13 runs; one startup failure had no downloadable log and is explicitly not
treated as a pass. All available logs passed Gitleaks and deterministic surface
checks. Path and identifier-shaped matches were limited to GitHub-hosted runner
internals. No run published a workflow artifact.

Dependency Review was rerun after public visibility. Attempt 2 of the original
pull-request run completed successfully for the `review` job on the release
head. Repository and Terraform validation were also successful.

## Original source archive

The original inspected archive contained 2,051 regular files and approximately
573 MiB. It was not safe to publish. Its blockers included private keys,
kubeconfig material, Azure/application secrets, hardcoded passwords,
state/backups/plans, credential-bearing archives, nested repositories, upstream
source copies, provider/CLI binaries, `Zone.Identifier` files, caches, raw
scanner reports, and unredacted screenshots.

Any real credential from that original archive must remain revoked or rotated.
The public repository was reconstructed rather than copied wholesale. The
historical repository remains private, unrelated through GitHub fork/network
metadata, and is not presented as the public project.
