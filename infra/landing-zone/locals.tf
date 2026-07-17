locals {
  tags = merge({
    environment = var.environment
    managed-by  = "terraform"
    owner       = var.owner_tag
    project     = "azure-data-landing-zone"
  }, var.additional_tags)
}
