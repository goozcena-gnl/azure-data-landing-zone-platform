# GitHub repository settings

## Current assessment

No repository setting, branch-protection rule, ruleset, environment, Actions
variable, secret, or OIDC credential was created or modified during
finalization.

The repository-rulesets API returned HTTP 403 while the repository was private:
the feature requires an organization-plan upgrade or public visibility. No
unenforced rule was created. GitHub documents repository rulesets as available
to public repositories on GitHub Free, so reassess immediately after an
authorized visibility change.

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

Do not apply the ruleset until a repository administrator confirms public
visibility, successful required checks, and ruleset enforcement availability.

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

Recommended settings:

- allow only required actions and reusable workflows;
- require immutable full commit SHA references;
- use read-only default workflow permissions;
- do not allow Actions to approve pull requests;
- keep fork pull-request workflow tokens read-only;
- enable Dependabot alerts and updates;
- enable secret scanning and push protection when the plan supports them;
- enable private vulnerability reporting for public release.

The repository policy test rejects mutable GitHub Action references. Workflow
permissions are declared explicitly.

## Self-hosted runner

The `azure-lab` runner must not execute untrusted pull-request code. Use an
ephemeral or reimaged host, no stored reusable Azure credential, a stable
allowlisted outbound address for the backend, current patches, restricted
network egress, and no access to unrelated repositories.

## Apply only after authorization

After the repository is public, all three checks have reported on the current
default-branch commit, and the maintainer explicitly authorizes the mutation:

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

Before making the repository public, confirm the clean release archive,
sanitized lifecycle evidence, third-party attribution, license, security
contact, default branch, topics, and README status statement. Public visibility
does not imply AKS, Jupyter, OIDC, or GitHub deployment validation.
