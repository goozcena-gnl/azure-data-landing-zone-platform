# Contributing

1. Branch from `main` and keep changes single-purpose.
2. Update documentation and examples with code changes.
3. Follow the [local-development guide](docs/local-development.md), then run
   `make doctor` and `make test-strict` in an isolated environment.
   The toolchain is version-constrained and partially reproducible; it is not
   a byte-for-byte identical or offline environment.
4. Review staged changes for credentials and generated files.
5. Open a pull request using the template.

Do not commit state, plans, credentials, kubeconfig, real identifiers, scanner dumps, binaries, or copied upstream repositories. Do not claim a plan, deployment, smoke test, or destroy passed without evidence. Provider/Terraform major upgrades and resource replacements require an explicit migration note.

Suggested logical commits:

```text
chore: sanitize repository for public release
refactor: reorganize terraform landing zone
fix: harden terraform providers and variables
ci: add github validation workflows
docs: add portfolio readme and lab runbooks
test: add infrastructure validation scripts
security: add scanning and disclosure policy
```
