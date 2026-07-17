locals {
  tags = merge({
    environment = "lab"
    managed-by  = "terraform"
    project     = "azure-data-landing-zone"
    purpose     = "terraform-state"
  }, var.additional_tags)
}
