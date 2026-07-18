# Azure lab deployment

## Preflight

The foundation lifecycle has already been validated and destroyed. A future
live run starts by creating a new dedicated backend; do not reuse the deleted
backend coordinates from private evidence.

```bash
az login --tenant "<tenant-id>"
az account set --subscription "<subscription-id>"
az account show \
  --query "{name:name,id:id,tenantId:tenantId}" \
  --output json
make test
```

For AKS, run the read-only gate before any plan:

```bash
bash ./scripts/aks-preflight.sh \
  --tfvars infra/landing-zone/terraform.tfvars \
  --json-output artifacts/aks-preflight.json
```

A non-zero result blocks AKS planning. The script never registers providers,
changes quota, creates a group, or selects a fallback region/SKU.

## Deploy foundation first

1. Follow [`backend-bootstrap.md`](backend-bootstrap.md).
2. Copy `infra/landing-zone/terraform.tfvars.example` to ignored `terraform.tfvars`.
3. Replace placeholders and keep `enable_aks=false` initially.
4. Run:

```bash
make test
make plan-lab
less artifacts/lab-plan.txt
make deploy-lab
make smoke-test
```

Reject unexpected deletes/replacements, public exposure, broad role assignments, unexpected SKUs/regions, or costly services.

## Optional AKS

```hcl
enable_aks                 = true
enable_jupyter             = false
location                   = "<explicit-azure-region>"
aks_node_vm_size           = "<explicit-deployable-vm-sku>"
aks_node_count             = 1
aks_admin_group_object_ids = ["<ENTRA_GROUP_OBJECT_ID>"]
aks_authorized_ip_ranges   = ["<PUBLIC_IP>/32"]
```

Prepare and validate the Entra group through
[`../entra/aks-admin-group.md`](../entra/aks-admin-group.md). The last
assessment found the default SKU unavailable in France Central and no eligible
admin group; no fallback was selected.

Generate a new saved plan and request explicit billable-action approval only
after the preflight passes. Never reuse the previously deleted foundation plan.

Create/review a new plan, apply it, then:

```bash
bash ./scripts/get-aks-credentials.sh
export KUBECONFIG="$PWD/artifacts/kubeconfig-lab"
kubectl get nodes
kubectl get pods -A
bash ./scripts/deploy-jupyter.sh
make smoke-test
```

Set `enable_jupyter=true` only to record post-AKS installation intent.
Terraform validates that it cannot be enabled without AKS, but the Helm phase
remains a separate manual action.
