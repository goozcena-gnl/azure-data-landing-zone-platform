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

variable "resource_group_name" {
  description = "AKS resource group name."
  type        = string
}

variable "subnet_id" {
  description = "AKS node subnet ID."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
  sensitive   = true
}

variable "admin_group_object_ids" {
  description = "Microsoft Entra group object IDs granted AKS administration."
  type        = list(string)
}

variable "kubernetes_version" {
  description = "Optional AKS Kubernetes version."
  type        = string
  default     = null
  nullable    = true
}

variable "node_vm_size" {
  description = "AKS system node VM size."
  type        = string
}

variable "node_count" {
  description = "AKS system node count."
  type        = number

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 3
    error_message = "The lab supports 1-3 system nodes."
  }
}

variable "private_cluster_enabled" {
  description = "Enable a private AKS API server."
  type        = bool
}

variable "authorized_ip_ranges" {
  description = "CIDRs allowed to reach a public AKS API server."
  type        = list(string)
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID."
  type        = string
}

variable "enable_monitoring" {
  description = "Enable Container Insights."
  type        = bool
}

variable "enable_azure_policy" {
  description = "Enable Azure Policy add-on."
  type        = bool
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
}
