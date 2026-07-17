resource "azurerm_user_assigned_identity" "cluster" {
  name                = "id-${var.name_prefix}-${var.environment}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "subnet_network_contributor" {
  scope                = var.subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.cluster.principal_id
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.name_prefix}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "aks-${var.name_prefix}-${var.environment}"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"

  role_based_access_control_enabled = true
  local_account_disabled            = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  private_cluster_enabled           = var.private_cluster_enabled
  azure_policy_enabled              = var.enable_azure_policy
  automatic_upgrade_channel         = var.kubernetes_version == null ? "patch" : null
  node_os_upgrade_channel           = "NodeImage"

  default_node_pool {
    name                 = "system"
    vm_size              = var.node_vm_size
    node_count           = var.node_count
    vnet_subnet_id       = var.subnet_id
    os_disk_size_gb      = 64
    os_disk_type         = "Managed"
    type                 = "VirtualMachineScaleSets"
    max_pods             = 50
    orchestrator_version = var.kubernetes_version

    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.cluster.id]
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    tenant_id              = var.tenant_id
    admin_group_object_ids = var.admin_group_object_ids
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    load_balancer_sku   = "standard"
    service_cidr        = "10.250.0.0/16"
    dns_service_ip      = "10.250.0.10"
    outbound_type       = "loadBalancer"
  }

  dynamic "api_server_access_profile" {
    for_each = var.private_cluster_enabled ? [] : [1]
    content {
      authorized_ip_ranges = var.authorized_ip_ranges
    }
  }

  dynamic "oms_agent" {
    for_each = var.enable_monitoring ? [1] : []
    content {
      log_analytics_workspace_id      = var.log_analytics_workspace_id
      msi_auth_for_monitoring_enabled = true
    }
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  dynamic "monitor_metrics" {
    for_each = var.enable_monitoring ? [1] : []
    content {}
  }

  tags = var.tags

  depends_on = [azurerm_role_assignment.subnet_network_contributor]

  lifecycle {
    precondition {
      condition     = var.private_cluster_enabled || length(var.authorized_ip_ranges) > 0
      error_message = "Public AKS requires at least one authorized_ip_ranges entry."
    }

    precondition {
      condition     = length(var.admin_group_object_ids) > 0
      error_message = "AKS requires at least one Microsoft Entra group object ID because local accounts are disabled."
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "diag-${var.name_prefix}-${var.environment}-aks"
  target_resource_id         = azurerm_kubernetes_cluster.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
