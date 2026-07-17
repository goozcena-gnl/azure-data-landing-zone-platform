output "cluster_name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.main.name
}

output "resource_group_name" {
  description = "AKS resource group name."
  value       = azurerm_kubernetes_cluster.main.resource_group_name
}

output "oidc_issuer_url" {
  description = "AKS OIDC issuer URL."
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "cluster_identity_principal_id" {
  description = "AKS user-assigned identity principal ID."
  value       = azurerm_user_assigned_identity.cluster.principal_id
}
