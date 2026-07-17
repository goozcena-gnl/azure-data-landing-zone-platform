# Troubleshooting

## Backend authorization failure

Check active Azure identity, storage firewall, and `Storage Blob Data Contributor`. Management-plane `Contributor` does not grant blob data access.

## Local backend succeeds but GitHub fails

The firewall may reject ephemeral hosted-runner addresses. Prefer a controlled self-hosted/private runner or a reviewed time-bounded rule; do not enable account keys/unrestricted public access.

## AKS precondition failure

Public AKS requires at least one authorized CIDR, and all AKS deployments require at least one Microsoft Entra admin group because local accounts are disabled.

## JupyterHub unreachable

The service is `ClusterIP`. Use `kubectl port-forward`, inspect Helm status/pods/events, and do not add public ingress merely to bypass validation.
