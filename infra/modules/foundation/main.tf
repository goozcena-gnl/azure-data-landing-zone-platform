resource "azurerm_resource_group" "network" {
  name     = "rg-${var.name_prefix}-${var.environment}-network"
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "management" {
  name     = "rg-${var.name_prefix}-${var.environment}-management"
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "platform" {
  name     = "rg-${var.name_prefix}-${var.environment}-platform"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.name_prefix}-${var.environment}"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  address_space       = var.address_space
  tags                = var.tags
}

resource "azurerm_network_security_group" "aks" {
  name                = "nsg-${var.name_prefix}-${var.environment}-aks"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  tags                = var.tags
}

resource "azurerm_network_security_group" "private_endpoints" {
  name                = "nsg-${var.name_prefix}-${var.environment}-private-endpoints"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  tags                = var.tags
}

resource "azurerm_network_security_group" "shared_services" {
  name                = "nsg-${var.name_prefix}-${var.environment}-shared"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  tags                = var.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_prefixes.aks]
}

resource "azurerm_subnet" "private_endpoints" {
  name                              = "snet-private-endpoints"
  resource_group_name               = azurerm_resource_group.network.name
  virtual_network_name              = azurerm_virtual_network.main.name
  address_prefixes                  = [var.subnet_prefixes.private_endpoints]
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_subnet" "shared_services" {
  name                 = "snet-shared-services"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_prefixes.shared_services]
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}

resource "azurerm_subnet_network_security_group_association" "shared_services" {
  subnet_id                 = azurerm_subnet.shared_services.id
  network_security_group_id = azurerm_network_security_group.shared_services.id
}

resource "azurerm_log_analytics_workspace" "main" {
  name                       = "log-${var.name_prefix}-${var.environment}"
  location                   = azurerm_resource_group.management.location
  resource_group_name        = azurerm_resource_group.management.name
  sku                        = "PerGB2018"
  retention_in_days          = var.log_retention_days
  daily_quota_gb             = 1
  internet_ingestion_enabled = true
  internet_query_enabled     = true
  tags                       = var.tags
}

resource "random_string" "key_vault_suffix" {
  count = var.enable_key_vault ? 1 : 0

  keepers = {
    name_prefix = var.name_prefix
    environment = var.environment
  }
  length  = 5
  upper   = false
  special = false
}

resource "azurerm_key_vault" "main" {
  count = var.enable_key_vault ? 1 : 0

  name                          = substr("kv${replace(var.name_prefix, "-", "")}${var.environment}${random_string.key_vault_suffix[0].result}", 0, 24)
  location                      = azurerm_resource_group.platform.location
  resource_group_name           = azurerm_resource_group.platform.name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  public_network_access_enabled = false
  purge_protection_enabled      = false
  soft_delete_retention_days    = 7
  tags                          = var.tags
}

resource "azurerm_private_dns_zone" "key_vault" {
  count = var.enable_key_vault ? 1 : 0

  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.network.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  count = var.enable_key_vault ? 1 : 0

  name                  = "link-${azurerm_virtual_network.main.name}-keyvault"
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault[0].name
  virtual_network_id    = azurerm_virtual_network.main.id
}

resource "azurerm_private_endpoint" "key_vault" {
  count = var.enable_key_vault ? 1 : 0

  name                = "pep-${azurerm_key_vault.main[0].name}"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${azurerm_key_vault.main[0].name}"
    private_connection_resource_id = azurerm_key_vault.main[0].id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "key-vault"
    private_dns_zone_ids = [azurerm_private_dns_zone.key_vault[0].id]
  }
}
