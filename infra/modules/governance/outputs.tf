output "policy_definition_ids" {
  description = "Custom policy definition IDs."
  value = merge(
    { allowed_locations = azurerm_policy_definition.allowed_locations.id },
    { for key, policy in azurerm_policy_definition.required_tag : "required_tag_${key}" => policy.id }
  )
}
