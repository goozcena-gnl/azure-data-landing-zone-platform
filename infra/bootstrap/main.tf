resource "random_string" "suffix" {
  keepers = {
    name_prefix = var.name_prefix
  }
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "state" {
  name     = "rg-${var.name_prefix}-state"
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "state" {
  name                              = substr("st${var.name_prefix}${random_string.suffix.result}", 0, 24)
  resource_group_name               = azurerm_resource_group.state.name
  location                          = azurerm_resource_group.state.location
  account_tier                      = "Standard"
  account_replication_type          = "LRS"
  account_kind                      = "StorageV2"
  min_tls_version                   = "TLS1_2"
  allow_nested_items_to_be_public   = false
  shared_access_key_enabled         = false
  public_network_access_enabled     = true
  infrastructure_encryption_enabled = true

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 14
    }

    container_delete_retention_policy {
      days = 14
    }
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices", "Logging", "Metrics"]
    ip_rules       = var.allowed_ip_addresses
  }

  tags = local.tags
}

resource "azurerm_storage_container" "state" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "state_blob_contributor" {
  count = var.grant_principal_id == null ? 0 : 1

  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.grant_principal_id
}
