# GitHub repository settings

## Current assessment

On 2026-07-20, API-verified public-repository hardening enabled GitHub secret
scanning for user alerts, push protection, and private vulnerability reporting.
Dependabot alerts and security updates remain enabled. The follow-up alert
inventory found zero secret-scanning alerts and zero Dependabot alerts at that
point in time.

The clean repository is public. The repository-rulesets API is available and
returned no configured rulesets. The historical repository remains private.
The payload below was validated against the successful public pull-request
checks, but no rule was created or activated.

Automatic partner scanning of public repositories is separate from repository
user alerts and push protection. Validity checks, extended metadata checks,
non-provider patterns, and custom patterns were not enabled: those advanced
capabilities require an organization and/or paid GitHub Secret Protection
entitlement that this user-owned repository does not have. CodeQL remains
deferred and was not enabled.

## Prepared main ruleset

The reviewed import payload is
[`main-ruleset.json`](main-ruleset.json). It is prepared but has not been
submitted. It targets only the default branch and has no bypass actor.

The payload requires:

- pull requests before changes reach `main`;
- zero approving reviews while there is only one trusted maintainer;
- conversation resolution;
- a current branch before merge;
- linear history with squash or rebase merge;
- the three GitHub Actions checks below;
- blocked force pushes and branch deletion.

| GitHub check | Ruleset context | Source |
| --- | --- | --- |
| `Validate / repository` | `repository` | GitHub Actions app `15368` |
| `Validate / terraform` | `terraform` | GitHub Actions app `15368` |
| `Dependency review / review` | `review` | GitHub Actions app `15368` |

GitHub's ruleset API uses the job context, not the displayed
`workflow / job` label. The job names are unique across repository workflows.
If a second trusted reviewer becomes available, increase
`required_approving_review_count` from `0` to `1`; do not enable
`require_last_push_approval` for a sole maintainer.

Do not apply the ruleset until a repository administrator explicitly
authorizes the mutation after confirming successful checks on the final pull
request head.

## Read-only assessment commands

After authenticating `gh`, an administrator can inspect current state:

```bash
gh repo view "<github-owner>/<repository>" \
  --json nameWithOwner,visibility,isPrivate,defaultBranchRef

gh api \
  "repos/<github-owner>/<repository>/branches/main/protection"

gh api \
  "repos/<github-owner>/<repository>/rulesets"

gh api \
  "repos/<github-owner>/<repository>/environments"

gh variable list --repo "<github-owner>/<repository>"
gh secret list --repo "<github-owner>/<repository>"
```

An HTTP 403, 404, or unavailable feature is not evidence that protection is
active. Record repository visibility, organization plan, and the exact API
result.

## Actions policy

Effective and recommended settings:

- allow only required actions and reusable workflows;
- require immutable full commit SHA references;
- use read-only default workflow permissions;
- do not allow Actions to approve pull requests;
- keep fork pull-request workflow tokens read-only;
- keep Dependabot alerts and security updates enabled;
- keep secret scanning user alerts and push protection enabled;
- keep private vulnerability reporting enabled;
- do not represent automatic partner scanning as equivalent to user alerts;
- defer CodeQL and paid or organization-only secret protections until separately
  authorized and entitled.

The repository policy test rejects mutable GitHub Action references. Workflow
permissions are declared explicitly. Secret scanning complements, but does not
replace, credential revocation, history review, or deterministic repository
scanning.

## Self-hosted runner

The `azure-lab` runner must not execute untrusted pull-request code. Use an
ephemeral or reimaged host, no stored reusable Azure credential, a stable
allowlisted outbound address for the backend, current patches, restricted
network egress, and no access to unrelated repositories.

## Apply only after authorization

After all three checks have reported on the final pull-request head and the
maintainer explicitly authorizes the mutation:

```bash
gh api \
  --method POST \
  -H "X-GitHub-Api-Version: 2026-03-10" \
  "repos/<github-owner>/<repository>/rulesets" \
  --input docs/github/main-ruleset.json
```

Verify the returned ruleset and effective rules with read-only GET requests,
then use a controlled pull request to prove that direct pushes, force pushes,
deletion, stale branches, unresolved conversations, and missing checks are
blocked. The command above is a mutation and must not be run without explicit
authorization.

## Publication settings

The repository is public, but public visibility does not imply AKS, Jupyter,
OIDC, or GitHub deployment validation. Before release, confirm the clean release
archive, sanitized lifecycle evidence, third-party attribution, license,
security contact, default branch, topics, and README status statement.
