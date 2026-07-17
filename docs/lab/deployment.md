# Azure lab deployment

## Preflight

```bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.PolicyInsights
az provider register --namespace Microsoft.KeyVault
az vm list-skus --location francecentral --size Standard_D2s_v5 --all -o table
az aks get-versions --location francecentral -o table
```

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
aks_admin_group_object_ids = ["<ENTRA_GROUP_OBJECT_ID>"]
aks_authorized_ip_ranges   = ["<PUBLIC_IP>/32"]
```

Create/review a new plan, apply it, then:

```bash
bash ./scripts/get-aks-credentials.sh
export KUBECONFIG="$PWD/artifacts/kubeconfig-lab"
kubectl get nodes
kubectl get pods -A
bash ./scripts/deploy-jupyter.sh
make smoke-test
```
