resource "azurerm_service_plan" "this" {
  name                = var.plan_name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = var.sku_name
  tags                = var.tags
}

resource "azurerm_linux_web_app" "this" {
  name                = var.app_name
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.this.id

  https_only                = true
  virtual_network_subnet_id = var.integration_subnet_id

  # Publish profiles are long-lived credentials; deploy with OIDC instead.
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  tags = var.tags

  identity {
    type = "SystemAssigned"
  }

  logs {
    detailed_error_messages = true
    failed_request_tracing  = true

    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }

  site_config {
    always_on              = true
    ftps_state             = "Disabled"
    http2_enabled          = true
    minimum_tls_version    = "1.2"
    app_command_line       = var.startup_command
    vnet_route_all_enabled = true

    health_check_path                 = "/"
    health_check_eviction_time_in_min = 5

    application_stack {
      node_version = var.node_version
    }

    # The service tag covers every Front Door customer, so the header pins it to ours.
    ip_restriction_default_action = "Deny"

    # Deployment tools reach the SCM site directly. Basic auth is off, so it needs Entra ID.
    scm_ip_restriction_default_action = "Allow"

    ip_restriction {
      name        = "AllowOurFrontDoor"
      action      = "Allow"
      priority    = 100
      service_tag = "AzureFrontDoor.Backend"

      headers {
        x_azure_fdid = [var.front_door_id]
      }
    }
  }
}
