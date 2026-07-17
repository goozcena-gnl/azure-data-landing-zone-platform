variable "name_prefix" {
  description = "Project prefix."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "resource_group_ids" {
  description = "Resource groups receiving policy assignments."
  type        = map(string)
}

variable "allowed_locations" {
  description = "Azure locations accepted by the location policy. Global-scope resources are always exempt."
  type        = list(string)
}

variable "required_tag_names" {
  description = "Tags audited by policy."
  type        = set(string)
}
