locals {
  # Application ID of the Microsoft-registered Azure VPN Client (Azure public cloud).
  azure_vpn_client_audience = "c632b3df-fb67-4d84-bdcf-b95ad541b5c8"
}

resource "azurerm_public_ip" "gateway" {
  name                = "pip-${var.gateway_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway" "this" {
  name                = var.gateway_name
  resource_group_name = var.resource_group_name
  location            = var.location
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = var.sku
  generation          = "Generation1"
  active_active       = false
  bgp_enabled         = false
  tags                = var.tags

  ip_configuration {
    name                          = "default"
    public_ip_address_id          = azurerm_public_ip.gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = var.gateway_subnet_id
  }

  vpn_client_configuration {
    address_space        = [var.p2s_address_pool]
    vpn_client_protocols = ["OpenVPN"]
    vpn_auth_types       = ["AAD"]
    aad_tenant           = "https://login.microsoftonline.com/${var.tenant_id}/"
    aad_audience         = local.azure_vpn_client_audience
    aad_issuer           = "https://sts.windows.net/${var.tenant_id}/"
  }
}

resource "azurerm_local_network_gateway" "onprem" {
  name                = "lgw-onpremises-001"
  resource_group_name = var.resource_group_name
  location            = var.location
  gateway_address     = var.onprem_gateway_ip
  address_space       = var.onprem_address_spaces
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway_connection" "s2s" {
  name                       = "con-${var.gateway_name}-onpremises"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  type                       = "IPsec"
  connection_protocol        = "IKEv2"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.this.id
  local_network_gateway_id   = azurerm_local_network_gateway.onprem.id
  shared_key                 = var.shared_key
  tags                       = var.tags
}
