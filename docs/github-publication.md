# GitHub publication and release procedure

## Current v0.1.0 gate

Pull request #5 was rebase-merged into `main` at
`f357c7db3652c0d645eff575153511186912209c`. The reviewed release branch was
deleted after the merge.

The clean replacement repository is public, while the historical repository
remains private. Secret scanning user alerts, push protection, private
vulnerability reporting, and the active `Protect main` ruleset are enabled.

No v0.1.0 artifact, tag, or GitHub Release exists yet. Release preparation is
blocked until the focused documentation-correction pull request is merged and
the complete post-merge validation and reproducibility gate passes on the new
exact `main` commit.

## Completed v0.1.0 gates

1. The clean replacement repository was created and made public.
2. The historical repository remained private and isolated.
3. Publication, history, pull-request, Actions-log, artifact, and protected-SHA
   audits passed.
4. Repository security protections were enabled and verified.
5. The `Protect main` ruleset was activated with no bypass actors and the
   required `repository`, `terraform`, and `review` checks.
6. Dependency Review passed after public visibility.
7. Pull request #5 passed its required checks, was rebase-merged, and its
   release branch was deleted.

## Remaining v0.1.0 gates

1. Merge the focused documentation-correction pull request.
2. Rerun complete validation on the new exact `main` commit.
3. Generate and independently reproduce the tracked-file-only release package.
4. Create and locally verify an annotated v0.1.0 tag.
5. Push the verified tag.
6. Publish the GitHub Release and its three assets.
7. Download the published assets and verify their checksums and ZIP contents.

Each mutation remains a separate authorization gate. Artifact generation does
not authorize tagging, tag publication, or GitHub Release publication.

Use the concise reviewed release summary as a pull-request body. Do not use the
complete execution report as a pull-request description.

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

The active [`Protect main` ruleset](github/main-ruleset.json) and the review
procedure in
[`GitHub repository settings`](github/repository-settings.md) protect only
`main`. The ruleset has no bypass actors and requires current successful
`repository`, `terraform`, and `review` checks, pull requests, linear history,
and conversation resolution. It blocks non-fast-forward updates and deletion.

Dependency Review is intentionally retained. Its `review` job context is one
of the three required GitHub Actions checks. The sole-maintainer baseline
requires zero approving reviews; it does not claim independent human approval.

## Reusable post-merge release procedure

Do not reuse a pre-merge archive. After the documentation-correction pull
request is merged and artifact generation is explicitly authorized, update
`main` and prove it matches the remote:

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

Return to the source checkout and confirm the exact final `main` SHA. Only
after separate tag, tag-push, and release-publication authorizations, use:

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
