data "azurerm_client_config" "current" {}

# Makes every globally unique name distinct across subscriptions.
resource "random_string" "suffix" {
  length  = 6
  lower   = true
  numeric = true
  upper   = false
  special = false
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-lab-aue-001"
  location = local.regions.aue
  tags     = local.tags
}

resource "azurerm_resource_group" "onp" {
  name     = "rg-onp-001"
  location = local.regions.onp
  tags     = local.tags
}

module "network" {
  source   = "../../modules/network"
  for_each = local.networks

  name                = each.value.name
  resource_group_name = each.value.resource_group
  location            = each.value.region
  address_space       = each.value.address_space
  subnets             = each.value.subnets
  nsg_name            = each.value.nsg_name
  nsg_rules           = each.value.nsg_rules
  tags                = local.tags
}

# Forwarded traffic and gateway transit let the Canada VNet reach on-premises and
# P2S clients through vng01, which lives in the Austria VNet.
resource "azurerm_virtual_network_peering" "aue_to_cac" {
  name                         = "peer-aue-to-cac"
  resource_group_name          = azurerm_resource_group.lab.name
  virtual_network_name         = module.network["aue"].name
  remote_virtual_network_id    = module.network["cac"].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = var.vpn_enabled

  depends_on = [module.hybrid_vpn]
}

resource "azurerm_virtual_network_peering" "cac_to_aue" {
  name                         = "peer-cac-to-aue"
  resource_group_name          = azurerm_resource_group.lab.name
  virtual_network_name         = module.network["cac"].name
  remote_virtual_network_id    = module.network["aue"].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = var.vpn_enabled && var.vpn_transit_enabled

  # Azure needs the gateway to exist, and transit enabled on the other side, first.
  depends_on = [module.hybrid_vpn, azurerm_virtual_network_peering.aue_to_cac]
}
