resource "azurerm_private_dns_zone" "file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "file" {
  for_each = { aue = module.network["aue"].id, cac = module.network["cac"].id }

  name                = "link-file-${each.key}"
  private_dns_zone_id = azurerm_private_dns_zone.file.id
  virtual_network_id  = each.value
  tags                = local.tags
}

# The media gallery is a browser app that calls Blob Storage directly, so this
# account's endpoint must stay reachable. CORS limits which sites may use it.
module "storage_blob" {
  source = "../../modules/storage"

  name                  = "stblob${random_string.suffix.result}"
  resource_group_name   = azurerm_resource_group.lab.name
  location              = local.regions.aue
  public_access_enabled = true
  containers            = ["media"]
  sas_max_lifetime      = "07.00:00:00" # The gallery holds an account SAS, pasted in by hand
  cors_allowed_origins = [
    "https://${module.front_door.endpoint_hostnames["webapp01"]}",
    "https://${module.web_app["webapp01"].default_hostname}",
  ]
  tags = local.tags
}

module "storage_files" {
  source = "../../modules/storage"

  name                  = "stfiles${random_string.suffix.result}"
  resource_group_name   = azurerm_resource_group.lab.name
  location              = local.regions.cac
  public_access_enabled = false
  file_shares           = { data = 100 }
  private_endpoint = {
    name                = "pe-stfiles-cac-001"
    subnet_id           = module.network["cac"].subnet_ids["snet-pvtendp-cac-003"]
    subresource         = "file"
    private_dns_zone_id = azurerm_private_dns_zone.file.id
  }
  tags = local.tags
}
