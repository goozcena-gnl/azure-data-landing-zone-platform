# Backend bootstrap

The backend used by the validated lifecycle was intentionally deleted. Every
future live run begins with a newly reviewed backend bootstrap. Backend
creation is an Azure mutation and can be billable; obtain approval first.

The expected lifecycle is:

```text
bootstrap backend
initialize landing-zone Terraform with explicit non-secret parameters
plan and apply the reviewed landing-zone plan
validate and smoke-test
destroy landing-zone resources and prove state is empty
verify residual Azure inventory
delete the separately managed backend only when recovery is no longer needed
```

## Terraform bootstrap root

```bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"
cp infra/bootstrap/terraform.tfvars.example infra/bootstrap/terraform.tfvars
# Replace placeholders and trusted public IPv4.
terraform -chdir=infra/bootstrap init
terraform -chdir=infra/bootstrap fmt -check
terraform -chdir=infra/bootstrap validate
terraform -chdir=infra/bootstrap plan -out=bootstrap.tfplan
terraform -chdir=infra/bootstrap show -no-color bootstrap.tfplan
terraform -chdir=infra/bootstrap apply bootstrap.tfplan
terraform -chdir=infra/bootstrap output -raw backend_hcl > infra/landing-zone/backend.hcl
chmod 600 infra/landing-zone/backend.hcl
rm -f infra/bootstrap/bootstrap.tfplan
```

## Idempotent Azure CLI helper

As an alternative to the Terraform bootstrap root, the reviewed helper can
create or reconcile the same dedicated pattern:

```bash
cd infra/landing-zone
../../terraform_backend_setup/terraform_setup.sh \
  --subscription-id "<subscription-id>" \
  --tenant-id "<tenant-id>" \
  --project "azure-data-landing-zone" \
  --environment "lab" \
  --location "<azure-region>" \
  --network-mode ip \
  --client-ip "<trusted-public-ipv4>" \
  --assign-rbac \
  --principal-object-id "<operator-or-ci-object-id>" \
  --principal-type "<User-or-ServicePrincipal>" \
  --backend-file backend.tf \
  --backend-config-file backend.hcl

export ARM_USE_AZUREAD=true
export ARM_USE_CLI=true
terraform init -backend-config=backend.hcl
```

Run `make backend-test` before using the helper. It uses structured JSON,
supported scoped/inherited Azure CLI 2.88 RBAC queries, and a
`purpose=terraform-state` safety tag. It never writes a storage key.

The operator/GitHub identity needs `Storage Blob Data Contributor` on the storage scope. Do not re-enable account keys as a workaround. A tightly restricted storage firewall may require a controlled self-hosted runner or time-bounded network change for GitHub-hosted runners.

## CI network access

The state account is default-deny. The deployment and destruction workflows use

## Deletion

Landing-zone destruction and backend deletion are different operations. Never
delete the backend before `terraform state list` is empty and residual checks
pass. Use the fail-closed procedure in [`destroy.md`](destroy.md) and
`scripts/delete-backend.sh`; do not treat deletion of the bootstrap Terraform
root alone as sufficient inventory evidence.
a self-hosted runner labelled `azure-lab`; allowlist its stable outbound IPv4
address in `allowed_ip_addresses`. Do not broadly open the backend to all
networks merely to support a hosted runner.
