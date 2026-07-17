resource "azurerm_policy_definition" "allowed_locations" {
  name         = "${var.name_prefix}-${var.environment}-allowed-locations"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "${var.name_prefix} ${var.environment}: allowed locations"
  description  = "Deny resources created outside the configured lab regions."

  metadata = jsonencode({
    category = "General"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    "if" = {
      allOf = [
        {
          field = "location"
          notIn = "[parameters('allowedLocations')]"
        },
        {
          field     = "location"
          notEquals = "global"
        }
      ]
    }
    "then" = {
      effect = "deny"
    }
  })

  parameters = jsonencode({
    allowedLocations = {
      type = "Array"
      metadata = {
        displayName = "Allowed locations"
      }
    }
  })
}

resource "azurerm_policy_definition" "required_tag" {
  for_each = var.required_tag_names

  name         = "${var.name_prefix}-${var.environment}-audit-tag-${replace(each.value, "_", "-")}"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "${var.name_prefix} ${var.environment}: audit ${each.value} tag"
  description  = "Audit resources missing the ${each.value} tag."

  metadata = jsonencode({
    category = "Tags"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    "if" = {
      field  = "[concat('tags[', parameters('tagName'), ']')]"
      exists = "false"
    }
    "then" = {
      effect = "audit"
    }
  })

  parameters = jsonencode({
    tagName = {
      type = "String"
      metadata = {
        displayName = "Tag name"
      }
    }
  })
}

resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  for_each = var.resource_group_ids

  name                 = "pa-allowed-locations-${each.key}"
  display_name         = "Allowed locations for ${each.key}"
  resource_group_id    = each.value
  policy_definition_id = azurerm_policy_definition.allowed_locations.id
  enforce              = true

  parameters = jsonencode({
    allowedLocations = {
      value = var.allowed_locations
    }
  })
}

resource "azurerm_resource_group_policy_assignment" "required_tag" {
  for_each = {
    for pair in setproduct(keys(var.resource_group_ids), tolist(var.required_tag_names)) :
    "${pair[0]}-${pair[1]}" => {
      resource_group_key = pair[0]
      tag                = pair[1]
    }
  }

  name                 = substr("pa-tag-${replace(each.value.tag, "_", "-")}-${each.value.resource_group_key}", 0, 64)
  display_name         = "Audit ${each.value.tag} tag on ${each.value.resource_group_key}"
  resource_group_id    = var.resource_group_ids[each.value.resource_group_key]
  policy_definition_id = azurerm_policy_definition.required_tag[each.value.tag].id
  enforce              = true

  parameters = jsonencode({
    tagName = {
      value = each.value.tag
    }
  })
}
