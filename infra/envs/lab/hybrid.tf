resource "random_password" "vpn_shared_key" {
  length  = 40
  special = false
}

resource "azurerm_key_vault_secret" "vpn_shared_key" {
  name         = "vpn-shared-key"
  key_vault_id = azurerm_key_vault.lab.id
  value        = random_password.vpn_shared_key.result
  content_type = "pre-shared key"

  depends_on = [time_sleep.key_vault_rbac]
}

module "hybrid_vpn" {
  source = "../../modules/hybrid_vpn"
  count  = var.vpn_enabled ? 1 : 0

  gateway_name          = "vng01"
  resource_group_name   = azurerm_resource_group.lab.name
  location              = local.regions.aue
  gateway_subnet_id     = module.network["aue"].subnet_ids["GatewaySubnet"]
  p2s_address_pool      = var.p2s_address_pool
  tenant_id             = data.azurerm_client_config.current.tenant_id
  onprem_gateway_ip     = module.vm["vm-fw-001"].public_ip_address
  onprem_address_spaces = [local.onp_cidr]
  shared_key            = random_password.vpn_shared_key.result
  tags                  = local.tags
}

# Sends on-premises traffic for Azure networks through the firewall VM.
resource "azurerm_route_table" "onp" {
  name                = "rt-onpremises-001"
  resource_group_name = azurerm_resource_group.onp.name
  location            = azurerm_resource_group.onp.location
  tags                = local.tags

  route {
    name                   = "to-vnet-aue"
    address_prefix         = local.aue_cidr
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = local.vms["vm-fw-001"].private_ip
  }

  route {
    name                   = "to-vnet-cac"
    address_prefix         = local.cac_cidr
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = local.vms["vm-fw-001"].private_ip
  }

  route {
    name                   = "to-p2s-clients"
    address_prefix         = var.p2s_address_pool
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = local.vms["vm-fw-001"].private_ip
  }
}

resource "azurerm_subnet_route_table_association" "onp" {
  subnet_id      = module.network["onp"].subnet_ids["snet-onpremises"]
  route_table_id = azurerm_route_table.onp.id
}

# IKE from the Azure gateway only. A separate rule because the gateway's IP comes
# from the module that also needs the firewall VM's IP.
resource "azurerm_network_security_rule" "onp_ike" {
  count = var.vpn_enabled ? 1 : 0

  name                        = "AllowIkeFromAzureGateway"
  resource_group_name         = azurerm_resource_group.onp.name
  network_security_group_name = module.network["onp"].nsg_name
  direction                   = "Inbound"
  access                      = "Allow"
  priority                    = 120
  protocol                    = "Udp"
  source_port_range           = "*"
  source_address_prefix       = module.hybrid_vpn[0].gateway_public_ip
  destination_address_prefix  = module.vm["vm-fw-001"].private_ip_address
  destination_port_ranges     = ["500", "4500"]
}

resource "azurerm_virtual_machine_run_command" "rras" {
  count = var.vpn_enabled ? 1 : 0

  name               = "configure-rras"
  location           = local.regions.onp
  virtual_machine_id = module.vm["vm-fw-001"].id
  tags               = local.tags

  source {
    script = file("${path.module}/../../scripts/configure-rras.ps1")
  }

  parameter {
    name  = "AzureGatewayIp"
    value = module.hybrid_vpn[0].gateway_public_ip
  }

  parameter {
    name  = "RemotePrefixes"
    value = join(",", [local.aue_cidr, local.cac_cidr, var.p2s_address_pool])
  }

  protected_parameter {
    name  = "SharedKey"
    value = random_password.vpn_shared_key.result
  }

  depends_on = [module.hybrid_vpn, azurerm_network_security_rule.onp_ike]
}
