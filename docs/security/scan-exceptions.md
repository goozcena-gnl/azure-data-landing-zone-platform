# Security scan exceptions

These exceptions apply only to the disposable personal Azure lab. They are not
claims that the controls are unnecessary, and they do not define a production
baseline. Each exception must be reassessed before persistent, shared, or
customer-data use.

## Exception register

| Check | Scope | Lab rationale | Compensating controls | Production position |
|---|---|---|---|---|
| `CKV_AZURE_33` | Terraform state storage | Queue service logging is not configured because the backend uses Blob storage only. | State container is private; shared-key access is disabled; access is via Entra ID and RBAC. | Configure diagnostic settings and retain audit logs according to the organization policy. |
| `CKV_AZURE_59` | Terraform state storage | Public network access is retained to permit a clean-clone workflow and GitHub-hosted runners. | Default network action is deny; only declared public IP ranges are allowed; shared-key access is disabled. | Use a private endpoint, private DNS, and a private/self-hosted runner. |
| `CKV_AZURE_110` | Optional lab Key Vault | Purge protection can prevent prompt teardown of a disposable lab. | Key Vault is disabled by default; no production data; dedicated lab scope; soft-delete retention remains configured. | Enable purge protection and an approved retention period. |
| `CKV_AZURE_115` | AKS API server | A public API endpoint is permitted as an explicit lab option for users without private connectivity. | At least one authorized CIDR is mandatory; local accounts are disabled; Entra Azure RBAC is required. | Prefer a private cluster with controlled administration paths. |
| `CKV_AZURE_117` | AKS node disks | A customer-managed disk-encryption set is excluded from the default disposable lab. | Azure platform-managed encryption applies; no production data is stored. | Use an approved disk-encryption strategy where required by policy or regulation. |
| `CKV_AZURE_170` | AKS control plane | The Free tier is deliberate to control personal-subscription cost. | Single-user lab, disposable environment, no availability claim. | Select a paid tier appropriate to the required SLA and support model. |
| `CKV_AZURE_206` | Terraform state storage | LRS is an explicit low-cost choice for a reproducible lab backend. | Blob versioning, change feed, and retention controls are enabled; state is not business data. | Select ZRS/GRS according to recovery objectives and regional availability. |
| `CKV_AZURE_226` | AKS node pool | Ephemeral OS disks are not required because support depends on VM size and cache capacity. | Managed OS disks simplify portability across lab subscriptions and regions. | Select a validated node SKU and ephemeral OS disks when performance and recovery requirements justify them. |
| `CKV_AZURE_227` | AKS node pool | Encryption at host is not a portable default across every subscription, region, and VM SKU. | Azure storage encryption remains enabled by the platform; no production data. | Enable the feature after validating subscription registration and VM support. |
| `CKV_AZURE_232` | AKS node pools | The one-node cost-controlled lab intentionally shares its system pool with demonstration workloads. | Workloads are non-production and disposable; resource requests/limits are required. | Use a dedicated system pool with `CriticalAddonsOnly` taint plus separate user pools. |
| `CKV2_AZURE_1` | Terraform state storage | Customer-managed keys add Key Vault cost, lifecycle coupling, and teardown complexity to the minimal lab. | Microsoft-managed encryption, Entra authorization, network restrictions, versioning, and retention are enabled. | Use customer-managed keys when required by the threat model or compliance baseline. |
| `CKV2_AZURE_21` | Terraform state storage | Blob read logging is not provisioned in the minimal bootstrap component. | RBAC is limited; shared keys are disabled; state versions are retained. | Send storage data-plane logs to an approved Log Analytics workspace or archive. |
| `CKV2_AZURE_33` | Terraform state storage | A private endpoint is excluded to preserve a reproducible workflow from personal workstations and hosted CI. | Storage firewall default-deny and explicit IP allowlisting are mandatory. | Use a private endpoint, private DNS, and private runner connectivity. |

## Governance

- Exception owner: repository maintainer.
- Review trigger: provider upgrade, shared deployment, persistent data, public
  release candidate, or a change to the threat model.
- Expiry: no exception is automatically permanent.
- CI behavior: Checkov remains blocking for every non-exempt finding.
- Evidence: a passing scan proves only that the configured policy completed; it
  does not prove that an Azure deployment is secure.
