# GitHub publication procedure

Do not publish until every credential found in the original archive has been
revoked or rotated and the private pilot CI is green.

## Recommended metadata

- Repository: `azure-data-landing-zone-platform`
- Description: `Cost-controlled Azure landing-zone lab with Terraform, policy, AKS, OIDC CI/CD, security checks, and reproducible validation.`
- Initial visibility: private
- Initial release: `v0.1.0-private-pilot`
- Topics: `azure`, `terraform`, `aks`, `devops`, `infrastructure-as-code`,
  `azure-devops`, `github-actions`, `cloud-security`, `landing-zone`,
  `platform-engineering`, `checkov`, `tflint`

## Local initialization

```bash
cd azure-data-landing-zone-platform
git init
git checkout -b main
git add .
git diff --cached --check
git status --short
git commit -m "chore: sanitize repository for private pilot"
```

Create an empty private repository in GitHub, then:

```bash
git remote add origin "git@github.com:<GITHUB_OWNER>/azure-data-landing-zone-platform.git"
git push -u origin main
```

For a reviewable import history, an alternative is to create a branch and draft
pull request after the first baseline commit:

```bash
git checkout -b release/private-pilot-v0.1.0
git push -u origin release/private-pilot-v0.1.0
gh pr create --draft \
  --base main \
  --head release/private-pilot-v0.1.0 \
  --title "chore: prepare sanitized Azure landing-zone private pilot" \
  --body-file docs/validation/execution-report.md
```

## Protection baseline

- require pull requests and one approval for `main`;
- require the `Validate` and dependency-review checks when available;
- require conversation resolution;
- block force pushes and branch deletion;
- restrict environment deployment branches to `main`;
- require reviewers for `azure-lab-apply` and `azure-lab-destroy`;
- retain plan artifacts for one day only;
- enable private vulnerability reporting and secret scanning where available;
- configure Dependabot for GitHub Actions and Python dependencies.

Dependency review on a private repository can require GitHub Advanced Security,
depending on the account and repository plan. Treat an unavailable check as a
platform limitation, not as a passed security control.
