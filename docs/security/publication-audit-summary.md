# Publication audit summary

## Current reachable Git repository

The release baseline at commit `2d59d81` was audited across `main`, the release
branch, four Dependabot branches, every reachable commit and blob, and all tags.
There were 14 reachable commits, 244 unique text blobs, and no tags.

Gitleaks 8.30.1 scanned the complete reachable history with full redaction and
reported zero leaks. Deterministic history searches also found no real:

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
limited to generic examples. No matched value is reproduced here.

The largest reachable blob was 51,758 bytes. Executable modes are limited to
shell/Python/Bats scripts with shebangs; no unexpected executable was found.

## GitHub publication surface

All 23 accessible workflow-run logs were downloaded and scanned with Gitleaks
8.30.1. No leak or personal email was found. Absolute Linux paths in those logs
were limited to GitHub-managed runner and Dependabot home directories. No
personal workstation path was present, and the runs published zero workflow
artifacts.

The draft PR body contained no personal absolute path, but it incorrectly used
the complete execution report and included a malformed paragraph. Replace it
with the concise reviewed release summary before publication.

Dependency Review did not evaluate the pull-request dependency diff because the
private repository does not have the required feature entitlement. The action
must remain enabled and be rerun after authorized public visibility.

## Unresolved metadata decision

Ten existing commits contain the maintainer's personal Gmail address in author
or committer metadata. It is not a credential and Gitleaks does not classify it
as a secret, but public visibility would expose it permanently through Git
history. Before making the repository public, the maintainer must either:

1. explicitly accept publication of that address; or
2. authorize a coordinated history rewrite to a verified GitHub no-reply
   address, followed by replacement of every affected remote branch and PR.

No history rewrite or force push is authorized by this document.

## Original source archive

The original inspected archive contained 2,051 regular files and approximately
573 MiB. It was not safe to publish. Its blockers included private keys,
kubeconfig material, Azure/application secrets, hardcoded passwords,
state/backups/plans, credential-bearing archives, nested repositories, upstream
source copies, provider/CLI binaries, `Zone.Identifier` files, caches, raw
scanner reports, and unredacted screenshots.

Any real credential from that original archive must remain revoked or rotated.
The public repository was reconstructed rather than copied wholesale, and the
detailed forensic inventory remains an offline audit artifact.
