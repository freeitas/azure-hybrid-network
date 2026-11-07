# A Recovery Services vault only protects resources in its own region.
module "backup" {
  source = "../../modules/backup"
  for_each = {
    aue = { vm_ids = { "vm-srv-aue-001" = module.vm["vm-srv-aue-001"].id }, file_shares = {} }
    cac = {
      vm_ids      = { "vm-app-cac-001" = module.vm["vm-app-cac-001"].id }
      file_shares = { data = { storage_account_id = module.storage_files.id, share_name = "data" } }
    }
  }

  vault_name          = "rsv-lab-${each.key}-001"
  resource_group_name = azurerm_resource_group.lab.name
  location            = local.regions[each.key]
  vm_ids              = each.value.vm_ids
  file_shares         = each.value.file_shares
  tags                = local.tags

  # Enabling protection installs a VM extension, which conflicts with a running command.
  depends_on = [module.storage_files, azurerm_virtual_machine_run_command.iis]
}

# Blob backup uses a Backup vault, a different service from Recovery Services.
resource "azurerm_data_protection_backup_vault" "blob" {
  name                = "bvault-lab-aue-001"
  resource_group_name = azurerm_resource_group.lab.name
  location            = local.regions.aue
  datastore_type      = "VaultStore"
  redundancy          = "LocallyRedundant"
  tags                = local.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_data_protection_backup_policy_blob_storage" "operational" {
  name                                   = "bkpol-blob-30d"
  vault_id                               = azurerm_data_protection_backup_vault.blob.id
  operational_default_retention_duration = "P30D"
}

resource "azurerm_role_assignment" "blob_backup" {
  scope                = module.storage_blob.id
  role_definition_name = "Storage Account Backup Contributor"
  principal_id         = azurerm_data_protection_backup_vault.blob.identity[0].principal_id
}

resource "time_sleep" "blob_backup_rbac" {
  create_duration = "60s"

  depends_on = [azurerm_role_assignment.blob_backup]
}

resource "azurerm_data_protection_backup_instance_blob_storage" "media" {
  name               = "bi-stblob-media"
  vault_id           = azurerm_data_protection_backup_vault.blob.id
  location           = local.regions.aue
  storage_account_id = module.storage_blob.id
  backup_policy_id   = azurerm_data_protection_backup_policy_blob_storage.operational.id

  depends_on = [time_sleep.blob_backup_rbac]
}
