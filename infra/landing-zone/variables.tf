variable "subscription_id" {
  description = "Target Azure subscription ID. Supply through TF_VAR_subscription_id or OIDC environment configuration."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a UUID."
  }
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.tenant_id))
    error_message = "tenant_id must be a UUID."
  }
}

variable "name_prefix" {
  description = "Short lowercase project prefix used in resource names."
  type        = string
  default     = "dlz"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,9}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must contain 3-11 lowercase letters, digits, or internal hyphens."
  }
}

variable "environment" {
  description = "Environment identifier."
  type        = string
  default     = "lab"

  validation {
    condition     = contains(["lab", "dev", "test"], var.environment)
    error_message = "environment must be lab, dev, or test."
  }
}

variable "location" {
  description = "Azure deployment region."
  type        = string
  default     = "francecentral"
}

variable "address_space" {
  description = "Landing-zone virtual network address space."
  type        = list(string)
  default     = ["10.40.0.0/16"]
}

variable "subnet_prefixes" {
  description = "Landing-zone subnet CIDRs."
  type = object({
    aks               = string
    private_endpoints = string
    shared_services   = string
  })
  default = {
    aks               = "10.40.0.0/22"
    private_endpoints = "10.40.8.0/24"
    shared_services   = "10.40.9.0/24"
  }
}

variable "enable_governance" {
  description = "Create custom Azure Policy definitions and resource-group assignments."
  type        = bool
  default     = true
}

variable "allowed_locations" {
  description = "Locations accepted by the custom location policy. Include global for global resources."
  type        = list(string)
  default     = ["francecentral", "global"]
}

variable "required_tag_names" {
  description = "Resource tags audited by governance policy."
  type        = set(string)
  default     = ["environment", "managed-by", "owner", "project"]
}

variable "enable_key_vault" {
  description = "Create a private Key Vault. Disabled by default to keep the minimal lab small."
  type        = bool
  default     = false
}

variable "enable_aks" {
  description = "Create the AKS platform."
  type        = bool
  default     = false
}

variable "aks_private_cluster_enabled" {
  description = "Use a private AKS API server."
  type        = bool
  default     = false
}

variable "aks_authorized_ip_ranges" {
  description = "CIDRs allowed to reach the public AKS API. Required for public AKS."
  type        = list(string)
  default     = []
}

variable "aks_admin_group_object_ids" {
  description = "Microsoft Entra group object IDs granted cluster administration. Use groups, not individual users."
  type        = list(string)
  default     = []
}

variable "aks_kubernetes_version" {
  description = "Optional Kubernetes version. Null uses Azure's regional default and patch upgrade channel."
  type        = string
  default     = null
  nullable    = true
}

variable "aks_node_vm_size" {
  description = "AKS system node VM size. Confirm availability and quota in the selected region."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "aks_node_count" {
  description = "AKS system node count."
  type        = number
  default     = 1
}

variable "enable_aks_monitoring" {
  description = "Enable Container Insights for AKS."
  type        = bool
  default     = true
}

variable "enable_aks_azure_policy" {
  description = "Enable the Azure Policy add-on for AKS."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Log Analytics retention in days."
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 90
    error_message = "The lab supports 30-90 days of retention."
  }
}

variable "owner_tag" {
  description = "Non-sensitive owner/team label used for cost allocation. Do not use an email address."
  type        = string
  default     = "portfolio"
}

variable "additional_tags" {
  description = "Additional non-sensitive tags."
  type        = map(string)
  default     = {}
}
