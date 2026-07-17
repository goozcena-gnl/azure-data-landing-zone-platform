# GitHub Actions authentication with Azure OIDC

Use one Microsoft Entra application/service principal with three narrowly
scoped federated credentials for the protected GitHub environments:

- `azure-lab-plan`: no reviewer required; permits reviewed planning only;
- `azure-lab-apply`: required reviewers; permits applying the exact plan from
  the same workflow run;
- `azure-lab-destroy`: required reviewers and typed confirmation.

The deployment workflows target a self-hosted runner labelled `azure-lab`.
Its fixed outbound IPv4 address must be included in the Terraform-state storage
firewall. Pull-request validation remains on GitHub-hosted runners and never
accesses the remote backend.

## Create the application

```bash
SUBSCRIPTION_ID="<SUBSCRIPTION_ID>"
GITHUB_OWNER="<GITHUB_OWNER>"
GITHUB_REPOSITORY="azure-data-landing-zone-platform"
APP_NAME="github-${GITHUB_REPOSITORY}-lab"

az account set --subscription "$SUBSCRIPTION_ID"
APP_ID="$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)"
APP_OBJECT_ID="$(az ad app show --id "$APP_ID" --query id -o tsv)"
az ad sp create --id "$APP_ID"
TENANT_ID="$(az account show --query tenantId -o tsv)"
```

## Create the federated credentials

```bash
for ENVIRONMENT in azure-lab-plan azure-lab-apply azure-lab-destroy; do
  FILE="$(mktemp)"
  cat > "$FILE" <<JSON
{
  "name": "github-${ENVIRONMENT}",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${GITHUB_OWNER}/${GITHUB_REPOSITORY}:environment:${ENVIRONMENT}",
  "audiences": ["api://AzureADTokenExchange"]
}
JSON
  az ad app federated-credential create \
    --id "$APP_OBJECT_ID" \
    --parameters "$FILE"
  rm -f "$FILE"
done
```

## RBAC model

The exact role design depends on whether Terraform creates resource groups,
policy definitions, and role assignments. This repository uses all three when
the corresponding feature flags are enabled.

| Scope | Minimum capability | Why |
| --- | --- | --- |
| State storage account | `Storage Blob Data Contributor` | Read/write/lock Terraform state using Entra data-plane authorization. |
| State storage account management plane | permission to read the account configuration | Required by backend discovery; the self-hosted runner IP is pre-authorized. |
| Subscription | custom deployment role, or `Contributor` for the isolated lab | Resource-group creation occurs at subscription scope. `Contributor` is justified only for this dedicated disposable subscription/lab scope. |
| Subscription | `Resource Policy Contributor` when governance is enabled | Create custom policy definitions and assignments. |
| Network resource group or AKS subnet | `Role Based Access Control Administrator` or a custom role limited to role assignments | Grant the AKS managed identity `Network Contributor` on its subnet. |

A lower-privilege pilot can set `enable_governance=false` and `enable_aks=false`,
but resource-group creation still needs subscription-level permission. In a
more mature design, provision resource groups separately and scope the GitHub
identity to those groups.

Do not grant `Owner`. Do not create a reusable client secret.

## GitHub variables and environments

Configure these as repository variables or duplicate them in the three
GitHub environments when separation is desired:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
TF_STATE_RESOURCE_GROUP
TF_STATE_STORAGE_ACCOUNT
TF_STATE_CONTAINER
TF_VAR_NAME_PREFIX
TF_VAR_LOCATION
TF_VAR_OWNER_TAG
TF_VAR_ENABLE_AKS
TF_VAR_AKS_AUTHORIZED_IP_RANGES
TF_VAR_AKS_ADMIN_GROUP_OBJECT_IDS
```

List variables must use Terraform JSON, for example:

```text
["203.0.113.10/32"]
```

Configure required reviewers for `azure-lab-apply` and
`azure-lab-destroy`. Restrict deployment branches to `main` and disable
self-approval where the GitHub plan supports it.
