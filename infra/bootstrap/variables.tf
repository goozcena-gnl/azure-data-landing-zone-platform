variable "subscription_id" {
  description = "Azure subscription ID used for backend bootstrap."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be a valid UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)."
  }
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.tenant_id))
    error_message = "tenant_id must be a valid UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)."
  }
}

variable "location" {
  description = "Azure region for the backend resources."
  type        = string
  default     = "francecentral"
}

variable "name_prefix" {
  description = "Short lowercase prefix used for backend resource names."
  type        = string
  default     = "dlzlab"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,9}$", var.name_prefix))
    error_message = "name_prefix must contain 3-10 lowercase letters or digits and start with a letter."
  }
}

variable "container_name" {
  description = "Blob container name used for Terraform state."
  type        = string
  default     = "tfstate"
}

variable "allowed_ip_addresses" {
  description = "Trusted public IPv4 addresses allowed to access the backend storage account, without CIDR suffixes."
  type        = list(string)

  validation {
    condition     = length(var.allowed_ip_addresses) > 0
    error_message = "At least one trusted public IPv4 address is required for backend bootstrap."
  }
}

variable "grant_principal_id" {
  description = "Optional object ID granted Storage Blob Data Contributor on the state storage account."
  type        = string
  default     = null
  nullable    = true
}

variable "additional_tags" {
  description = "Additional non-sensitive tags."
  type        = map(string)
  default     = {}
}
