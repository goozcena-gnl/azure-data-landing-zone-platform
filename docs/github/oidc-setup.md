# GitHub Actions OIDC setup

## Current status

The workflows request only `contents: read` and `id-token: write` for Azure
deployment. No reusable Azure client secret is referenced. Federated
credentials and GitHub variables are not currently configured, and no
GitHub-driven Azure deployment has been validated.

All commands below are preparation examples with placeholders. They were not
executed during repository finalization.

## Trust model

Use environment-scoped OpenID Connect subjects:

```text
repo:<github-owner>/<repository>:environment:azure-lab-plan
repo:<github-owner>/<repository>:environment:azure-lab-apply
repo:<github-owner>/<repository>:environment:azure-lab-destroy
```

Separate application registrations or managed identities for plan, apply, and
destroy give the clearest least-privilege boundary. If one identity is reused,
the three environment subjects must still be separate federated credentials.
The audience is `api://AzureADTokenExchange` and the issuer is
`https://token.actions.githubusercontent.com`.

## Create an application identity

An Entra administrator with application-management permission must review and
run this mutation:

```bash
APP_ID=$(az ad app create \
  --display-name "azure-dlz-github-<plan|apply|destroy>" \
  --query appId \
  --output tsv)

az ad sp create --id "$APP_ID"
```

Resolve and retain the application object ID in a private operator session:

```bash
APP_OBJECT_ID=$(az ad app show --id "$APP_ID" --query id --output tsv)
```

Create one federated credential per environment subject. Example parameter
file:

```json
{
  "name": "github-azure-lab-plan",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<github-owner>/<repository>:environment:azure-lab-plan",
  "description": "GitHub Actions plan environment",
  "audiences": ["api://AzureADTokenExchange"]
}
```

Apply only after review:

```bash
az ad app federated-credential create \
  --id "$APP_OBJECT_ID" \
  --parameters "<reviewed-federated-credential.json>"
```

Repeat with unique names and the exact `azure-lab-apply` and
`azure-lab-destroy` subjects for those identities.

## Azure RBAC

Grant at the narrowest workable scope:

- plan identity: read access to planned Azure scopes plus `Storage Blob Data
  Contributor` on the backend storage account;
- apply/destroy identity: the resource-management permissions required by the
  reviewed Terraform, plus `Storage Blob Data Contributor` on the backend;
- governance: permission to manage custom policy definitions and assignments;
- optional AKS: permission to create the subnet role assignment, normally
  `Role Based Access Control Administrator` at the narrow relevant scope.

Avoid `Owner` when narrower custom or built-in roles cover the operations.
Example commands, to be adjusted after an RBAC design review:

```bash
az role assignment create \
  --assignee-object-id "<service-principal-object-id>" \
  --assignee-principal-type ServicePrincipal \
  --role "<reviewed-role>" \
  --scope "<reviewed-azure-scope>"

az role assignment create \
  --assignee-object-id "<service-principal-object-id>" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "<backend-storage-resource-id>"
```

## GitHub variable inventory

The exact workflow variable names are:

| Variable | Purpose | Format |
| --- | --- | --- |
| `AZURE_CLIENT_ID` | Environment-specific OIDC application/client ID | UUID |
| `AZURE_TENANT_ID` | Entra tenant | UUID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription | UUID |
| `TF_STATE_RESOURCE_GROUP` | Dedicated backend resource group | string |
| `TF_STATE_STORAGE_ACCOUNT` | Backend storage account | lowercase Azure name |
| `TF_STATE_CONTAINER` | Private backend container | lowercase Azure name |
| `TF_STATE_KEY` | Landing-zone state blob key | `landing-zone/lab.tfstate` |
| `TF_VAR_NAME_PREFIX` | Resource name prefix | 3-11 lowercase characters |
| `TF_VAR_LOCATION` | Explicit Azure region | canonical region name |
| `TF_VAR_OWNER_TAG` | Non-sensitive owner/team tag | no email address |
| `TF_VAR_ENABLE_AKS` | Enable optional AKS | `true` or `false` |
| `TF_VAR_ENABLE_JUPYTER` | Declare post-AKS Jupyter intent | `true` or `false` |
| `TF_VAR_AKS_NODE_VM_SIZE` | Explicit system-node SKU | Azure Standard SKU |
| `TF_VAR_AKS_NODE_COUNT` | System-node count | `1`, `2`, or `3` |
| `TF_VAR_AKS_AUTHORIZED_IP_RANGES` | Public API CIDRs | JSON list of CIDRs |
| `TF_VAR_AKS_ADMIN_GROUP_OBJECT_IDS` | Entra security-group IDs | JSON UUID list |

These are GitHub Environment variables in the current workflows. No
`AZURE_CLIENT_SECRET` is required or permitted.

## Verification

Before authorizing apply:

1. inspect each federated subject through Entra;
2. confirm no wildcard subject exists;
3. confirm environment reviewers and deployment branches;
4. run the plan workflow with `apply=false`;
5. inspect the one-day sensitive plan artifact;
6. approve apply only when the commit marker, plan checksum, and plan content
   match the reviewed change.
