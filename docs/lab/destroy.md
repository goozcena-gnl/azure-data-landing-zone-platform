# Destroy and cleanup

## Landing-zone destruction

Review a saved delete-only plan and apply that exact file:

```bash
az login --tenant "<tenant-id>"
az account set --subscription "<subscription-id>"
export TF_VAR_name_prefix="<name-prefix>"
make destroy-lab
```

Do not delete the backend first. Terraform needs it to track and destroy the
landing-zone resources.

## Residual verification

```bash
az resource list --tag project=azure-data-landing-zone -o table
az group list --query "[?contains(name, '<name-prefix>')].name" -o tsv
az policy definition list \
  --query "[?contains(name, '<name-prefix>')].name" \
  -o tsv
az policy assignment list \
  --query "[?contains(name, '<name-prefix>')].name" \
  -o tsv
az disk list -o table
az network public-ip list -o table
az network lb list -o table
az network nic list -o table
```

Confirm remote state is empty:

```bash
terraform -chdir=infra/landing-zone state list
terraform -chdir=infra/landing-zone output -json
```

The first command must print no managed resource addresses. The second must be
an empty object before backend deletion is considered.

## Separate backend deletion

The backend is not part of the landing-zone state. Delete it only when state
recovery is no longer required and every previous gate is recorded.

```bash
export AZURE_SUBSCRIPTION_ID="<subscription-id>"
export TF_STATE_RESOURCE_GROUP="<dedicated-backend-resource-group>"
export TF_STATE_STORAGE_ACCOUNT="<backend-storage-account>"
export TF_STATE_CONTAINER="<backend-container>"
export TF_STATE_KEY="landing-zone/lab.tfstate"

bash ./scripts/delete-backend.sh
```

The helper:

1. matches the active subscription without printing its ID;
2. proves remote state has zero managed resources;
3. requires the `purpose=terraform-state` resource-group tag;
4. requires exactly one named storage account in that group;
5. requires exactly one named container and no unrelated active blob;
6. displays the exact resource group, account, container, and key;
7. requires `DELETE-BACKEND:<resource-group>`;
8. deletes only that dedicated resource group;
9. waits and verifies that the group and storage account are absent.

It uses Entra data-plane authentication and never retrieves a storage key.

Finally remove ignored local material:

```bash
rm -f infra/landing-zone/backend.hcl
rm -rf artifacts/
```

The 2026-07-18 lifecycle completed all of these stages. It must not be inferred
that a future run is clean without repeating the read-only verification.
