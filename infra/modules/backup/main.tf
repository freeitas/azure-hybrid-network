resource "azurerm_recovery_services_vault" "this" {
  name                = var.vault_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  storage_mode_type   = "LocallyRedundant"
  tags                = var.tags
}

# Trusted Launch VMs require an Enhanced (V2) policy.
resource "azurerm_backup_policy_vm" "daily" {
  name                = "bkpol-vm-daily"
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.this.name
  policy_type         = "V2"
  timezone            = "UTC"

  instant_restore_retention_days = 5

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = var.retention_days
  }
}

resource "azurerm_backup_protected_vm" "this" {
  for_each = var.vm_ids

  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.this.name
  source_vm_id        = each.value
  backup_policy_id    = azurerm_backup_policy_vm.daily.id
}

resource "azurerm_backup_policy_file_share" "daily" {
  count = length(var.file_shares) > 0 ? 1 : 0

  name                = "bkpol-files-daily"
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.this.name
  timezone            = "UTC"

  backup {
    frequency = "Daily"
    time      = "23:30"
  }

  retention_daily {
    count = var.retention_days
  }
}

resource "azurerm_backup_container_storage_account" "this" {
  for_each = var.file_shares

  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.this.name
  storage_account_id  = each.value.storage_account_id
}

resource "azurerm_backup_protected_file_share" "this" {
  for_each = var.file_shares

  resource_group_name       = var.resource_group_name
  recovery_vault_name       = azurerm_recovery_services_vault.this.name
  source_storage_account_id = azurerm_backup_container_storage_account.this[each.key].storage_account_id
  source_file_share_name    = each.value.share_name
  backup_policy_id          = azurerm_backup_policy_file_share.daily[0].id
}
