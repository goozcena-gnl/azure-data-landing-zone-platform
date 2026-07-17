output "resource_group_name" {
  description = "Resource group containing the backend."
  value       = azurerm_resource_group.state.name
}

output "storage_account_name" {
  description = "Storage account containing Terraform state."
  value       = azurerm_storage_account.state.name
}

output "container_name" {
  description = "Blob container containing Terraform state."
  value       = azurerm_storage_container.state.name
}

output "backend_hcl" {
  description = "Sanitized backend configuration containing no credential."
  value = <<-EOT
  resource_group_name  = "${azurerm_resource_group.state.name}"
  storage_account_name = "${azurerm_storage_account.state.name}"
  container_name       = "${azurerm_storage_container.state.name}"
  key                  = "landing-zone/lab.tfstate"
  use_azuread_auth     = true
  EOT
}
