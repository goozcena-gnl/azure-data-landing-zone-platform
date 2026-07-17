# JupyterHub lab overlay

This directory contains only project-owned configuration. The upstream Jupyter Docker Stacks and JupyterHub source repositories are not vendored.

The lab script pins JupyterHub chart version `4.4.0`. Dummy authentication is limited to a private personal lab and the service remains `ClusterIP`. Use a temporary local port-forward for validation:

```bash
export KUBECONFIG="$PWD/artifacts/kubeconfig-lab"
kubectl -n jupyter port-forward service/proxy-public 8080:80
```

Replace dummy authentication with Microsoft Entra ID or another supported OAuth provider before any shared deployment.

## Container image reproducibility

The current lab overlay uses the upstream `python-3.12` convenience tag. Before
creating empirical release evidence, resolve that tag to a reviewed immutable
digest and record the digest in the validation evidence. A mutable tag is not
accepted as a production supply-chain control.
