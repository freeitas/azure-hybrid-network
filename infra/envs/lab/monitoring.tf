locals {
  resource_groups = {
    lab = azurerm_resource_group.lab.id
    onp = azurerm_resource_group.onp.id
  }

  # Built-in policy "Require a tag on resources".
  require_tag_policy_id = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
  required_tags         = ["environment", "project", "owner", "managed_by"]

  tag_policy_assignments = {
    for pair in setproduct(keys(local.resource_groups), local.required_tags) :
    "${pair[0]}-${pair[1]}" => { group = pair[0], tag = pair[1] }
  }
}

resource "azurerm_log_analytics_workspace" "lab" {
  name                = "log-lab-aue-001"
  resource_group_name = azurerm_resource_group.lab.name
  location            = local.regions.aue
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_monitor_diagnostic_setting" "front_door" {
  name                       = "to-log-analytics"
  target_resource_id         = azurerm_cdn_frontdoor_profile.lab.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.lab.id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "to-log-analytics"
  target_resource_id         = azurerm_key_vault.lab.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.lab.id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "vpn_gateway" {
  count = var.vpn_enabled ? 1 : 0

  name                       = "to-log-analytics"
  target_resource_id         = module.hybrid_vpn[0].gateway_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.lab.id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_action_group" "admins" {
  name                = "ag-lab-admins"
  resource_group_name = azurerm_resource_group.lab.name
  short_name          = "labadmins"
  tags                = local.tags

  email_receiver {
    name          = "admin-email"
    email_address = var.alert_email
  }
}

resource "azurerm_monitor_activity_log_alert" "vpn_health" {
  count = var.vpn_enabled ? 1 : 0

  name                = "alert-vpn-s2s-health"
  resource_group_name = azurerm_resource_group.lab.name
  location            = "global"
  scopes              = [azurerm_resource_group.lab.id]
  description         = "The site-to-site VPN connection stopped being healthy."
  tags                = local.tags

  criteria {
    category    = "ResourceHealth"
    resource_id = module.hybrid_vpn[0].connection_id

    resource_health {
      current = ["Degraded", "Unavailable"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.admins.id
  }
}

resource "azurerm_consumption_budget_resource_group" "lab" {
  for_each = local.resource_groups

  name              = "budget-${each.key}"
  resource_group_id = each.value
  amount            = var.monthly_budget
  time_grain        = "Monthly"

  time_period {
    start_date = var.budget_start_date
  }

  notification {
    enabled        = true
    operator       = "GreaterThan"
    threshold      = 80
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }

  notification {
    enabled        = true
    operator       = "GreaterThan"
    threshold      = 100
    threshold_type = "Forecasted"
    contact_emails = [var.alert_email]
  }
}

# Reports missing tags without blocking deployments (enforce = false). Subnets and
# peerings cannot hold tags, and this policy's Indexed mode already ignores them.
resource "azurerm_resource_group_policy_assignment" "require_tag" {
  for_each = local.tag_policy_assignments

  name                 = "require-tag-${each.value.tag}"
  resource_group_id    = local.resource_groups[each.value.group]
  policy_definition_id = local.require_tag_policy_id
  enforce              = false
  parameters           = jsonencode({ tagName = { value = each.value.tag } })
}
