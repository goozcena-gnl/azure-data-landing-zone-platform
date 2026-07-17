# Backend bootstrap

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

The operator/GitHub identity needs `Storage Blob Data Contributor` on the storage scope. Do not re-enable account keys as a workaround. A tightly restricted storage firewall may require a controlled self-hosted runner or time-bounded network change for GitHub-hosted runners.

## CI network access

The state account is default-deny. The deployment and destruction workflows use
a self-hosted runner labelled `azure-lab`; allowlist its stable outbound IPv4
address in `allowed_ip_addresses`. Do not broadly open the backend to all
networks merely to support a hosted runner.
