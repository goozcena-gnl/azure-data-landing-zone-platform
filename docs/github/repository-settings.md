# GitHub repository settings

## Current assessment

No repository setting, branch-protection rule, ruleset, environment, Actions
variable, secret, or OIDC credential was created or modified during
finalization.

The prior assessment found that the desired branch-protection rule would not
be enforced under the repository's current organization plan. Creating an
unenforced rule would provide false assurance, so no branch-protection mutation
is recommended until repository visibility or organization licensing changes.

## Target protection baseline

When GitHub confirms enforcement for this repository:

- require pull requests into `main`;
- require at least one approval;
- dismiss stale approvals after material changes;
- require conversation resolution;
- require the `Validate` checks;
- include the dependency-review check only when GitHub makes it available;
- block force pushes and branch deletion;
- apply the rule to administrators where organizational policy permits;
- restrict deployment environments to reviewed branches.

Do not copy commands from this document into a live repository before a
repository administrator confirms the rule target and enforcement status.

## Read-only assessment commands

After authenticating `gh`, an administrator can inspect current state:

```bash
gh repo view "<github-owner>/<repository>" \
  --json nameWithOwner,visibility,isPrivate,defaultBranchRef

gh api \
  "repos/<github-owner>/<repository>/branches/main/protection"

gh api \
  "repos/<github-owner>/<repository>/environments"

gh variable list --repo "<github-owner>/<repository>"
gh secret list --repo "<github-owner>/<repository>"
```

An HTTP 404 or unavailable feature is not evidence that protection is active.
Record repository visibility, organization plan, and the exact API result.

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

## Suggested commands after enforcement becomes available

Prefer the GitHub web interface or a reviewed ruleset payload because supported
fields change over time. If automation is approved, save the exact JSON payload
in a private change record and use:

```bash
gh api \
  --method PUT \
  "repos/<github-owner>/<repository>/branches/main/protection" \
  --input "<reviewed-protection-payload.json>"
```

This is a mutation and requires explicit authorization. Verify afterwards with
a read-only GET and a controlled pull-request test.

## Publication settings

Before making the repository public, confirm the clean release archive,
sanitized lifecycle evidence, third-party attribution, license, security
contact, default branch, topics, and README status statement. Public visibility
does not imply AKS, Jupyter, OIDC, or GitHub deployment validation.
