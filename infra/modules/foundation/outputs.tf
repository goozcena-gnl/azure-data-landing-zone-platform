output "resource_group_names" {
  description = "Created resource group names."
  value = {
    network    = azurerm_resource_group.network.name
    management = azurerm_resource_group.management.name
    platform   = azurerm_resource_group.platform.name
  }
}

output "resource_group_ids" {
  description = "Created resource group IDs."
  value = {
    network    = azurerm_resource_group.network.id
    management = azurerm_resource_group.management.id
    platform   = azurerm_resource_group.platform.id
  }
}

output "virtual_network_id" {
  description = "Landing-zone virtual network ID."
  value       = azurerm_virtual_network.main.id
}

output "aks_subnet_id" {
  description = "AKS subnet ID."
  value       = azurerm_subnet.aks.id
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID."
  value       = azurerm_log_analytics_workspace.main.id
}

output "key_vault_id" {
  description = "Key Vault ID when enabled."
  value       = try(azurerm_key_vault.main[0].id, null)
}
