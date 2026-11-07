resource "random_password" "vm" {
  for_each = local.vms

  length           = 24
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!@#%^*-_=+"
}

resource "azurerm_key_vault" "lab" {
  name                       = "kv-lab-${random_string.suffix.result}"
  resource_group_name        = azurerm_resource_group.lab.name
  location                   = azurerm_resource_group.lab.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 7
  tags                       = local.tags
}

resource "azurerm_role_assignment" "deployer_secrets" {
  scope                = azurerm_key_vault.lab.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# New role assignments take a while to reach Key Vault.
resource "time_sleep" "key_vault_rbac" {
  create_duration = "60s"

  depends_on = [azurerm_role_assignment.deployer_secrets]
}

resource "azurerm_key_vault_secret" "vm_password" {
  for_each = local.vms

  name         = "${each.key}-admin-password"
  key_vault_id = azurerm_key_vault.lab.id
  value        = random_password.vm[each.key].result
  content_type = "password"

  depends_on = [time_sleep.key_vault_rbac]
}

module "vm" {
  source   = "../../modules/windows_vm"
  for_each = local.vms

  name                  = each.key
  resource_group_name   = local.networks[each.value.network].resource_group
  location              = local.networks[each.value.network].region
  subnet_id             = module.network[each.value.network].subnet_ids[each.value.subnet]
  size                  = var.vm_size
  image_version         = var.image_version
  admin_username        = var.admin_username
  admin_password        = random_password.vm[each.key].result
  public_ip_dns_label   = try(each.value.public_ip, false) ? "${each.key}-${random_string.suffix.result}" : null
  ip_forwarding_enabled = try(each.value.ip_forwarding, false)
  private_ip_address    = try(each.value.private_ip, null)
  shutdown_time         = var.shutdown_time
  shutdown_timezone     = var.shutdown_timezone
  tags                  = local.tags
}

module "web_app" {
  source = "../../modules/web_app"
  for_each = {
    webapp01 = { network = "aue", subnet = "snet-lab-aue-002", plan = "aplan-lab-aue-001", startup_command = "pm2 serve /home/site/wwwroot --no-daemon --spa" }
    webapp02 = { network = "cac", subnet = "snet-lab-cac-002", plan = "aplan-lab-cac-001", startup_command = null }
  }

  plan_name             = each.value.plan
  app_name              = "${each.key}-${random_string.suffix.result}"
  resource_group_name   = azurerm_resource_group.lab.name
  location              = local.networks[each.value.network].region
  integration_subnet_id = module.network[each.value.network].subnet_ids[each.value.subnet]
  startup_command       = each.value.startup_command
  front_door_id         = azurerm_cdn_frontdoor_profile.lab.resource_guid
  tags                  = local.tags
}

resource "azurerm_virtual_machine_run_command" "iis" {
  for_each = local.web_server_vms

  name               = "bootstrap-iis"
  location           = local.networks[each.value.network].region
  virtual_machine_id = module.vm[each.key].id
  tags               = local.tags

  source {
    script = file("${path.module}/../../scripts/bootstrap-iis.ps1")
  }

  parameter {
    name  = "FrontDoorId"
    value = azurerm_cdn_frontdoor_profile.lab.resource_guid
  }

  parameter {
    name  = "UrlRewriteMsiUrl"
    value = var.url_rewrite_msi_url
  }

  parameter {
    name  = "UrlRewriteMsiSha256"
    value = var.url_rewrite_msi_sha256
  }

  parameter {
    name  = "AdminPoolPrefix"
    value = join(".", slice(split(".", var.p2s_address_pool), 0, 3))
  }

  dynamic "protected_parameter" {
    for_each = contains(nonsensitive(keys(var.app_packages)), each.key) ? toset(["AppPackageUrl", "AppPackageSha256"]) : toset([])

    content {
      name  = protected_parameter.value
      value = protected_parameter.value == "AppPackageUrl" ? var.app_packages[each.key].url : var.app_packages[each.key].sha256
    }
  }
}
