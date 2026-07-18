# Microsoft Entra AKS administrator group

AKS local accounts are disabled. Cluster administration therefore requires at
least one security-enabled Microsoft Entra group object ID. Individual user
object IDs must not be placed in `aks_admin_group_object_ids`.

## Read-only discovery

Authenticate and select the intended tenant and subscription:

```bash
az login --tenant "<tenant-id>"
az account set --subscription "<subscription-id>"
```

Discover security-enabled groups without printing object IDs:

```bash
bash ./scripts/entra-aks-admin-group.sh \
  --search "azure-dlz" \
  --output table
```

Rerun with `--show-object-ids` only in a controlled local terminal when an ID
must be selected:

```bash
bash ./scripts/entra-aks-admin-group.sh \
  --search "azure-dlz" \
  --show-object-ids
```

Validate the selected stable object ID:

```bash
bash ./scripts/entra-aks-admin-group.sh \
  --group-id "<entra-security-group-object-id>"
```

Display names are discovery metadata, not stable identifiers. Store only the
validated object ID in the ignored `terraform.tfvars` file or protected GitHub
Environment variable:

```hcl
aks_admin_group_object_ids = ["<entra-security-group-object-id>"]
```

## Creating a dedicated group

Creation is a separate, auditable Entra mutation. The authenticated principal
normally needs an appropriate directory role or Microsoft Graph
`Group.ReadWrite.All`; organizational policy can impose stricter approval.
Confirm that authority before running any command.

The following commands are examples only and were not executed during project
finalization:

```bash
az ad group create \
  --display-name "azure-dlz-lab-aks-admins" \
  --mail-nickname "azure-dlz-lab-aks-admins"

az ad group show \
  --group "<new-group-object-id>" \
  --query "{id:id,displayName:displayName,securityEnabled:securityEnabled}" \
  --output json
```

Add approved human administrators as group members only after directory-owner
approval. Do not grant the users directly in Terraform:

```bash
az ad group member add \
  --group "<new-group-object-id>" \
  --member-id "<approved-user-object-id>"
```

Record:

- approving owner;
- change ticket or reason;
- group object ID in the protected configuration;
- membership decision;
- date and command result in a private audit system.

Do not copy directory IDs or user metadata into public evidence.

## Final readiness checks

```bash
bash ./scripts/aks-preflight.sh \
  --location "<azure-region>" \
  --vm-size "<explicit-vm-sku>" \
  --node-count 1 \
  --enable-aks true \
  --enable-jupyter false \
  --admin-group-id "<entra-security-group-object-id>" \
  --json-output artifacts/aks-preflight.json
```

The JSON artifact is ignored and written with owner-only permissions. A
non-zero exit indicates a blocking provider, version, SKU, quota,
configuration, or group condition. The preflight is read-only; it does not
register providers, raise quota, create groups, or deploy AKS.
