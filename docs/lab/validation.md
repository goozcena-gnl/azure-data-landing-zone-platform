# Lab validation and evidence

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
