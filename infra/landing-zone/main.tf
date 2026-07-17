module "foundation" {
  source = "../modules/foundation"

  name_prefix        = var.name_prefix
  environment        = var.environment
  location           = var.location
  address_space      = var.address_space
  subnet_prefixes    = var.subnet_prefixes
  log_retention_days = var.log_retention_days
  enable_key_vault   = var.enable_key_vault
  tenant_id          = var.tenant_id
  tags               = local.tags
}

module "governance" {
  count  = var.enable_governance ? 1 : 0
  source = "../modules/governance"

  name_prefix        = var.name_prefix
  environment        = var.environment
  resource_group_ids = module.foundation.resource_group_ids
  allowed_locations  = var.allowed_locations
  required_tag_names = var.required_tag_names
}

module "aks" {
  count  = var.enable_aks ? 1 : 0
  source = "../modules/aks"

  name_prefix                = var.name_prefix
  environment                = var.environment
  location                   = var.location
  resource_group_name        = module.foundation.resource_group_names.platform
  subnet_id                  = module.foundation.aks_subnet_id
  tenant_id                  = var.tenant_id
  admin_group_object_ids     = var.aks_admin_group_object_ids
  kubernetes_version         = var.aks_kubernetes_version
  node_vm_size               = var.aks_node_vm_size
  node_count                 = var.aks_node_count
  private_cluster_enabled    = var.aks_private_cluster_enabled
  authorized_ip_ranges       = var.aks_authorized_ip_ranges
  log_analytics_workspace_id = module.foundation.log_analytics_workspace_id
  enable_monitoring          = var.enable_aks_monitoring
  enable_azure_policy        = var.enable_aks_azure_policy
  tags                       = local.tags
}
