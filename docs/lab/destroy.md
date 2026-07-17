# Destroy and cleanup

```bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"
export TF_VAR_name_prefix="<NAME_PREFIX>"
make destroy-lab
```

Then check for remnants:

```bash
az resource list --tag project=azure-data-landing-zone -o table
az group list --query "[?contains(name, '<NAME_PREFIX>')].name" -o tsv
az disk list -o table
az network public-ip list -o table
```

Destroy the backend only after every component is removed and state recovery is no longer needed:

```bash
terraform -chdir=infra/bootstrap plan -destroy -out=bootstrap-destroy.tfplan
terraform -chdir=infra/bootstrap apply bootstrap-destroy.tfplan
rm -f infra/bootstrap/bootstrap-destroy.tfplan infra/landing-zone/backend.hcl
rm -rf artifacts/
```
