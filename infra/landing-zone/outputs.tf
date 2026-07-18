output "resource_group_names" {
  description = "Created resource groups."
  value       = module.foundation.resource_group_names
}

output "virtual_network_id" {
  description = "Landing-zone virtual network ID."
  value       = module.foundation.virtual_network_id
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID."
  value       = module.foundation.log_analytics_workspace_id
}

output "key_vault_id" {
  description = "Private Key Vault ID when enabled."
  value       = module.foundation.key_vault_id
}

output "aks_cluster_name" {
  description = "AKS cluster name when enabled."
  value       = try(module.aks[0].cluster_name, null)
}

output "aks_resource_group_name" {
  description = "AKS resource group name when enabled."
  value       = try(module.aks[0].resource_group_name, null)
}

output "aks_oidc_issuer_url" {
  description = "AKS workload-identity issuer URL when enabled."
  value       = try(module.aks[0].oidc_issuer_url, null)

}
output "jupyter_installation_enabled" {
  description = "Post-AKS JupyterHub installation intent. JupyterHub is deployed separately with Helm."
  value       = var.enable_jupyter
}
