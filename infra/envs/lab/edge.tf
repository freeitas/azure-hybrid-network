resource "azurerm_cdn_frontdoor_profile" "lab" {
  name                = "fdoor-lab-001"
  resource_group_name = azurerm_resource_group.lab.name
  sku_name            = "Standard_AzureFrontDoor"
  tags                = local.tags
}

module "front_door" {
  source = "../../modules/front_door"

  profile_id = azurerm_cdn_frontdoor_profile.lab.id
  sites = {
    "srv-aue"  = { host_name = module.vm["vm-srv-aue-001"].public_fqdn, origin_protocol = "Http" }
    "app-cac"  = { host_name = module.vm["vm-app-cac-001"].public_fqdn, origin_protocol = "Http" }
    "webapp01" = { host_name = module.web_app["webapp01"].default_hostname, origin_protocol = "Https" }
    "webapp02" = { host_name = module.web_app["webapp02"].default_hostname, origin_protocol = "Https" }
  }
  tags = local.tags
}
