# GitHub deployment environments

## Required environments

The workflow names are fixed and must match the OIDC subjects:

| Environment | Job | Recommended gate |
| --- | --- | --- |
| `azure-lab-plan` | read/refresh and saved plan | deployment branch restriction |
| `azure-lab-apply` | exact saved-plan apply | required reviewer and branch restriction |
| `azure-lab-destroy` | destroy plan and apply | required reviewer, branch restriction, typed input |

These environments do not currently exist. Creating them is a GitHub
repository-administration action and was not performed during finalization.

## Variable placement

Configure all variables listed in [`oidc-setup.md`](oidc-setup.md) in every
environment that uses them. Environment-specific `AZURE_CLIENT_ID` values allow
separate Azure identities while keeping one workflow interface.

Keep the region, node SKU, node count, optional-component flags, backend
coordinates, and Terraform inputs identical between plan and apply. The apply
job downloads the plan from the same workflow run, verifies its SHA-256, and
checks that `planned-commit.txt` equals `GITHUB_SHA`. It also compares a
SHA-256 fingerprint of every backend and Terraform input, so environment drift
between plan and apply fails closed without publishing the underlying values.

No environment secret is required for Azure authentication. If a future tool
needs a secret, document why, scope it to one environment, rotate it, and never
expose it to pull-request workflows.

## Protection recommendations

For `azure-lab-plan`:

- restrict deployment branches to `main` or explicitly approved release
  branches;
- optionally require a reviewer when plans may expose sensitive values;
- use the read-only plan Azure identity.

For `azure-lab-apply`:

- require at least one qualified infrastructure reviewer;
- prevent self-approval where the GitHub plan supports it;
- restrict deployment to the reviewed branch;
- use the apply identity only.

For `azure-lab-destroy`:

- require at least one qualified reviewer;
- restrict deployment to the reviewed branch;
- retain the workflow's exact `DESTROY-LAB` input;
- use a dedicated destroy identity where practical.

GitHub availability of required reviewers, branch rules, and self-review
prevention depends on repository visibility and account plan. Verify that the
selected protections are actually enforced before treating them as a security
control.

## Concurrency and artifacts

Plan, apply, and destroy share:

```yaml
concurrency:
  group: azure-lab-state
  cancel-in-progress: false
```

This serializes state-affecting workflows. Do not change the group between
deployment and destroy workflows.

The binary plan, checksum, human-readable plan, and commit marker are treated
as potentially sensitive and retained for one day. Cleanup runs with
`if: always()` on the self-hosted runner. The artifact must not be attached to
a public issue or release.

## Fork and trigger boundary

Deployment and destroy use `workflow_dispatch`; they do not run on pull
requests or arbitrary pushes. Pull-request workflows have only
`contents: read`, do not request an OIDC token, and do not reference deployment
environment variables.

## Administrative checklist

After an authorized administrator creates the environments:

```text
[ ] Names exactly match the workflow and OIDC subjects
[ ] Deployment branches are restricted
[ ] Apply and destroy have required reviewers
[ ] Environment variables are complete and consistent
[ ] No long-lived Azure client secret exists
[ ] Federated credential subject is exact, not wildcarded
[ ] Self-hosted runner is isolated and uses label azure-lab
[ ] A plan-only workflow run succeeds before any apply approval
```
