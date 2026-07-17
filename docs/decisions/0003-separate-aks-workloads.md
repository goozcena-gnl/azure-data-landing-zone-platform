# ADR 0003: Separate AKS provisioning from workloads

- Status: Accepted
- Date: 2026-07-14

The original root attempted to configure Kubernetes/Helm providers using credentials from a cluster created in the same apply. The new design provisions AKS with Terraform, then obtains an isolated kubeconfig and installs a pinned chart in a separate phase. This avoids broken initialization and limits credential exposure.
