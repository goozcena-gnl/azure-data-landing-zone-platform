variable "name_prefix" {
  description = "Project naming prefix."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "address_space" {
  description = "Virtual network address spaces."
  type        = list(string)
}

variable "subnet_prefixes" {
  description = "Subnet address prefixes."
  type = object({
    aks               = string
    private_endpoints = string
    shared_services   = string
  })
}

variable "log_retention_days" {
  description = "Log Analytics retention in days."
  type        = number
}

variable "enable_key_vault" {
  description = "Create a private Key Vault."
  type        = bool
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
}
