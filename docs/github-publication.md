# GitHub publication and release procedure

## Current gate

The release work continues on `release/foundation-lifecycle-validation` through
draft pull request #5. Do not merge it, mark it ready, change visibility, create
rulesets or environments, or publish a release without explicit authorization.

Before public visibility:

1. resolve all actionable validation failures on the pull-request head;
2. keep dependency review enabled and record any private-plan limitation;
3. review the full reachable Git history, workflow logs, artifacts, and PR text;
4. resolve or explicitly accept publication of personal commit metadata;
5. obtain authorization for the visibility change;
6. rerun dependency review, secret scanning, and the complete validation suite
   after the repository is public.

Use the concise reviewed release summary as the PR body. Do not use the complete
execution report as the PR description.

## Recommended public metadata

- Repository: `azure-data-landing-zone-platform`
- Description: `Cost-controlled Azure landing-zone lab with Terraform, policy, AKS, OIDC CI/CD, security checks, and reproducible validation.`
- Initial public release: `v0.1.0`
- Topics: `azure`, `terraform`, `aks`, `devops`, `infrastructure-as-code`,
  `azure-devops`, `github-actions`, `cloud-security`, `landing-zone`,
  `platform-engineering`, `checkov`, `tflint`

The foundation lifecycle is empirically validated. AKS, JupyterHub, GitHub OIDC,
protected environments, and GitHub-driven deployment remain explicit
exclusions.

## Protection baseline

After public visibility and successful post-publication checks, use the
prepared [`main` ruleset](github/main-ruleset.json) and the review procedure in
[`GitHub repository settings`](github/repository-settings.md). The ruleset is
not active until an administrator explicitly submits it.

Dependency review is intentionally retained. An unavailable check on the
current private plan is a platform limitation, not a passed security control.
It must run successfully after public visibility before the ruleset is applied.

## Post-merge release procedure

Do not reuse a pre-merge archive. After PR #5 is merged and release creation is
explicitly authorized, update `main` and prove it matches the remote:

```bash
git switch main
git pull --ff-only origin main
test -z "$(git status --porcelain --untracked-files=normal)"
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)"
```

Create a new empty output directory outside the repository, then regenerate the
tracked-file-only archive, manifest, and checksums:

```bash
RELEASE_DIR="<absolute-empty-release-output-directory>"
mkdir -p "$RELEASE_DIR"
OUTPUT_DIR="$RELEASE_DIR" \
  bash scripts/package-release.sh --output-dir "$RELEASE_DIR" --version v0.1.0
sha256sum -c "$RELEASE_DIR/SHA256SUMS"
```

The package command creates and verifies:

- `azure-data-landing-zone-platform-v0.1.0.zip`;
- `file-manifest.csv`;
- `SHA256SUMS`.

Extract the exact ZIP again into a separate clean directory and rerun the static
suite from the extracted repository root:

```bash
mkdir "$RELEASE_DIR/extracted"
unzip -q "$RELEASE_DIR/azure-data-landing-zone-platform-v0.1.0.zip" \
  -d "$RELEASE_DIR/extracted"
cd "$RELEASE_DIR/extracted/azure-data-landing-zone-platform-v0.1.0"

make test
terraform fmt -check -recursive
make validate
make terraform-test
tflint --init
tflint --recursive
make security
make backend-test
bats terraform_backend_setup/tests/terraform_setup.bats
make docs-check
markdownlint-cli --config .markdownlint.json '**/*.md'
python3 tests/repository_policy.py
python3 scripts/secret-scan.py --root .
```

The extracted archive has no `.git` directory, so the final `git diff --check`
is not applicable there. Run it in the clean source checkout immediately before
packaging, and record `NOT APPLICABLE` for that extracted-copy step.

Return to the source checkout, confirm the final main SHA, then create the
annotated tag and release only after separate authorization:

```bash
cd "<absolute-source-repository-directory>"
FINAL_SHA=$(git rev-parse HEAD)
git tag -a v0.1.0 "$FINAL_SHA" \
  -m "v0.1.0: validated Azure foundation lifecycle"
git push origin v0.1.0

gh release create v0.1.0 \
  --repo "<github-owner>/<repository>" \
  --verify-tag \
  --title "v0.1.0 — Validated Azure foundation lifecycle" \
  --notes-file CHANGELOG.md \
  "$RELEASE_DIR/azure-data-landing-zone-platform-v0.1.0.zip" \
  "$RELEASE_DIR/file-manifest.csv" \
  "$RELEASE_DIR/SHA256SUMS"
```

Verify the published tag and downloadable assets in a second clean directory:

```bash
gh release view v0.1.0 \
  --repo "<github-owner>/<repository>" \
  --json tagName,targetCommitish,isDraft,isPrerelease,url,assets

gh release download v0.1.0 \
  --repo "<github-owner>/<repository>" \
  --dir "<absolute-clean-download-directory>"
cd "<absolute-clean-download-directory>"
sha256sum -c SHA256SUMS
unzip -t azure-data-landing-zone-platform-v0.1.0.zip
```

Release rollback means deleting the GitHub Release and remote tag only after a
separate explicit decision; never silently move or replace a published tag.
