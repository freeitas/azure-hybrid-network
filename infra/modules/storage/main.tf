resource "azurerm_storage_account" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  account_tier                     = "Standard"
  account_replication_type         = "LRS"
  min_tls_version                  = "TLS1_2"
  https_traffic_only_enabled       = true
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
  default_to_oauth_authentication  = true
  public_network_access            = var.public_access_enabled ? "Enabled" : "Disabled"

  tags = var.tags

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }

    dynamic "cors_rule" {
      for_each = length(var.cors_allowed_origins) > 0 ? [1] : []

      content {
        allowed_origins    = var.cors_allowed_origins
        allowed_methods    = ["GET", "PUT", "DELETE", "OPTIONS", "HEAD"]
        allowed_headers    = ["*"]
        exposed_headers    = ["*"]
        max_age_in_seconds = 3600
      }
    }
  }

  share_properties {
    retention_policy {
      days = 7
    }
  }

  network_rules {
    default_action = var.public_access_enabled ? "Allow" : "Deny"
    bypass         = ["AzureServices"]
  }

  sas_policy {
    expiration_period = var.sas_max_lifetime
    expiration_action = "Block"
  }
}

resource "azurerm_storage_container" "this" {
  for_each = var.containers

  name                  = each.value
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

resource "azurerm_storage_share" "this" {
  for_each = var.file_shares

  name               = each.key
  storage_account_id = azurerm_storage_account.this.id
  quota              = each.value
}

resource "azurerm_private_endpoint" "this" {
  count = var.private_endpoint == null ? 0 : 1

  name                = var.private_endpoint.name
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.private_endpoint.name}-connection"
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = [var.private_endpoint.subresource]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_endpoint.private_dns_zone_id]
  }
}
