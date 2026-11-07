# Creates the remote state store. Its own state stays local because the backend
# cannot exist before this runs.

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  numeric = true
  upper   = false
  special = false
}

locals {
  tags = {
    project    = "azure-hybrid-network"
    owner      = var.owner
    managed_by = "terraform"
    purpose    = "terraform-state"
  }
}

resource "azurerm_resource_group" "state" {
  name     = "rg-tfstate-001"
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "state" {
  name                = "sttfstate${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.state.name
  location            = azurerm_resource_group.state.location

  account_tier                     = "Standard"
  account_replication_type         = "LRS"
  min_tls_version                  = "TLS1_2"
  https_traffic_only_enabled       = true
  allow_nested_items_to_be_public  = false
  shared_access_key_enabled        = false
  default_to_oauth_authentication  = true
  cross_tenant_replication_enabled = false

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  network_rules {
    default_action = length(var.allowed_ips) > 0 ? "Deny" : "Allow"
    ip_rules       = var.allowed_ips
    bypass         = ["AzureServices"]
  }

  tags = local.tags
}

resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "state_contributor" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "state_ci" {
  for_each = var.ci_principal_ids

  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value
}

resource "azurerm_management_lock" "state" {
  name       = "protect-terraform-state"
  scope      = azurerm_storage_account.state.id
  lock_level = "CanNotDelete"
  notes      = "Holds Terraform state, which contains VM passwords and the VPN shared key."
}
