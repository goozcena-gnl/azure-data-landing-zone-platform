# GitHub publication and release procedure

## Published v0.1.0 reference

Pull request #5 was rebase-merged with historical merge result
`f357c7db3652c0d645eff575153511186912209c`. Pull request #6 was
rebase-merged with historical merge result
`13e964ad48139c2201fd5bf5823634fe2e763caf`. Both merges passed the active
`Protect main` ruleset without a bypass, and both source branches were deleted.

The clean replacement repository is public, while the historical repository
remains private. Secret scanning user alerts, push protection, private
vulnerability reporting, and the active `Protect main` ruleset are enabled.

The annotated `v0.1.0` tag and GitHub Release were published on 2026-07-28 from
commit `e66ce2a54d624206f4a81014fa265521137e41b5`. The release includes the
tracked-file archive, file manifest, and checksums. The tag remains the
immutable repository reference.

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
8. Pull request #6 passed its required checks, was rebase-merged, and its
   documentation branch was deleted.
9. The exact release commit passed the release validation and packaging suite.
10. The annotated tag and GitHub Release were published with three assets.
11. The published assets were downloaded and independently verified.

## Future release gates

1. Select and validate the exact `main` commit for the release.
2. Generate and independently verify the release artifacts.
3. Create, verify, and publish a new annotated version tag.
4. Publish the GitHub Release and its assets.
5. Download the published assets and verify their checksums and ZIP contents.

Each mutation remains a separate authorization gate. Artifact generation does
not authorize tagging, tag publication, or GitHub Release publication.

Use the concise reviewed release summary as a pull-request body. Do not use the
complete execution report as a pull-request description.

## Recommended public metadata

- Repository: `azure-data-landing-zone-platform`
- Description: `Terraform-based Azure landing-zone lab with modular networking, governance, secure remote state, GitHub Actions, and a validated foundation lifecycle.`
- Initial public release: `v0.1.0`
- Topics: `azure`, `terraform`, `azure-landing-zones`,
  `infrastructure-as-code`, `cloud-platform`, `azure-governance`,
  `azure-policy`, `github-actions`, `devsecops`, `aks`

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

Do not reuse a pre-merge archive. After all changes selected for the release
are merged and artifact generation is explicitly authorized, update `main`
and prove it matches the remote:

```bash
git switch main
git pull --ff-only origin main
test -z "$(git status --porcelain --untracked-files=normal)"
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)"
```

Create a new empty output directory outside the repository, then regenerate the
tracked-file-only archive, manifest, and checksums:

```bash
RELEASE_VERSION="<new-version>"
RELEASE_DIR="<absolute-empty-release-output-directory>"
mkdir -p "$RELEASE_DIR"
OUTPUT_DIR="$RELEASE_DIR" \
  bash scripts/package-release.sh --output-dir "$RELEASE_DIR" \
  --version "$RELEASE_VERSION"
sha256sum -c "$RELEASE_DIR/SHA256SUMS"
```

The package command creates and verifies:

- `azure-data-landing-zone-platform-$RELEASE_VERSION.zip`;
- `file-manifest.csv`;
- `SHA256SUMS`.

Extract the exact ZIP again into a separate clean directory and rerun the static
suite from the extracted repository root:

```bash
mkdir "$RELEASE_DIR/extracted"
unzip -q "$RELEASE_DIR/azure-data-landing-zone-platform-$RELEASE_VERSION.zip" \
  -d "$RELEASE_DIR/extracted"
cd "$RELEASE_DIR/extracted/azure-data-landing-zone-platform-$RELEASE_VERSION"

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

Return to the source checkout and confirm the exact release-candidate commit.
Only after separate tag, tag-push, and release-publication authorizations, use:

```bash
cd "<absolute-source-repository-directory>"
RELEASE_SHA=$(git rev-parse HEAD)
git tag -a "$RELEASE_VERSION" "$RELEASE_SHA" \
  -m "$RELEASE_VERSION: validated Azure foundation lifecycle"
git push origin "$RELEASE_VERSION"

gh release create "$RELEASE_VERSION" \
  --repo "<github-owner>/<repository>" \
  --verify-tag \
  --title "$RELEASE_VERSION — Validated Azure foundation lifecycle" \
  --notes-file CHANGELOG.md \
  "$RELEASE_DIR/azure-data-landing-zone-platform-$RELEASE_VERSION.zip" \
  "$RELEASE_DIR/file-manifest.csv" \
  "$RELEASE_DIR/SHA256SUMS"
```

Verify the published tag and downloadable assets in a second clean directory:

```bash
gh release view "$RELEASE_VERSION" \
  --repo "<github-owner>/<repository>" \
  --json tagName,targetCommitish,isDraft,isPrerelease,url,assets

gh release download "$RELEASE_VERSION" \
  --repo "<github-owner>/<repository>" \
  --dir "<absolute-clean-download-directory>"
cd "<absolute-clean-download-directory>"
sha256sum -c SHA256SUMS
unzip -t "azure-data-landing-zone-platform-$RELEASE_VERSION.zip"
```

Release rollback means deleting the GitHub Release and remote tag only after a
separate explicit decision; never silently move or replace a published tag.
