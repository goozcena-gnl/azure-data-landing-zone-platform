# Lab validation and evidence

## Recorded lifecycle

The 2026-07-18 foundation-only run passed plan, exact apply, no-drift refresh,
foundation smoke tests, exact destroy, empty-state verification, residual
inventory, and separate backend deletion. The sanitized record is
[`../validation/2026-07-18-foundation-lifecycle.md`](../validation/2026-07-18-foundation-lifecycle.md).

That result does not include AKS, Entra AKS administration, JupyterHub, GitHub
OIDC, GitHub Environment approvals, or the GitHub-controlled deployment
workflow.

Use only sanitized counts, hashes, component flags, and redacted placeholders
in committed evidence. Keep raw plan text, state, kubeconfig, IDs, network
addresses, CLI debug logs, and JSON preflight output under ignored local
artifacts.

## Foundation commands

Foundation commands:

```bash
terraform -chdir=infra/landing-zone output -json
az group list --tag project=azure-data-landing-zone -o table
az network vnet list -o table
az monitor log-analytics workspace list -o table
az policy assignment list -o table
```

AKS commands:

```bash
export KUBECONFIG="$PWD/artifacts/kubeconfig-lab"
kubectl wait --for=condition=Ready nodes --all --timeout=10m
kubectl get nodes -o wide
kubectl get pods -A -o wide
helm list -A
```

Example Log Analytics query after ingestion delay:

```kusto
KubePodInventory
| where TimeGenerated > ago(30m)
| summarize Pods=count() by ClusterName, Namespace
| order by Pods desc
```

Every evidence summary must state UTC date, environment, commit, tool versions, command, result, sanitized evidence, and limitations. Never commit state, binary plans, kubeconfig, full identifiers, tokens, or large raw reports.

## Required status vocabulary

| Status | Meaning |
| --- | --- |
| `PASS` | The command executed and objective evidence supports success. |
| `FAIL` | The command executed and objective evidence supports failure. |
| `BLOCKED` | Permission, credentials, network, quota, or a missing tool prevented execution. |
| `NOT RUN` | The test was not attempted. |
| `NOT APPLICABLE` | The test is outside the selected scope. |

A timeout is not a pass. A local scanner pass is recorded separately from an
optional remote integration failure.
