# Third-party attribution and dependency decisions

The original workspace contained complete copies or downloaded artifacts from
several upstream projects. The sanitized repository keeps only project-owned
configuration and documentation.

| Component | Likely origin | Licensing observed/expected | Archive decision | Publishable representation |
| --- | --- | --- | --- | --- |
| Jupyter Docker Stacks | `jupyter/docker-stacks` | BSD-3-Clause upstream | Complete clean checkout externalized | Use a pinned upstream container image; add only a project-owned Dockerfile overlay if customization is required. |
| JupyterHub Helm chart | `jupyterhub/zero-to-jupyterhub-k8s` | BSD-3-Clause upstream | Upstream source not retained | Pinned chart version plus `platform/jupyter/values.lab.yaml`. |
| Azure Naming Tool | Microsoft/Azure upstream repository | MIT upstream | Complete source copy removed because authorship/modification history was unclear | Deploy a pinned release, container image, or clearly attributed fork. |
| Inframap | `cycloidio/inframap` | Upstream license applies | Source tree and downloaded binary removed | Install as a documentation tool in a disposable environment; do not commit its binary. |
| Terraform providers and CLIs | HashiCorp/Microsoft/Kubernetes toolchains | Vendor licenses apply | Downloaded binaries and `.terraform` removed | Declare versions; download in CI with integrity verification where practical. |

## Authorship boundary

The MIT license at the repository root covers only project-owned Terraform,
scripts, workflow configuration, documentation, and overlays. It does not
relicense upstream applications, Helm charts, container images, tools, or
providers. A future fork must preserve the upstream license and notices and
must clearly identify local modifications.
