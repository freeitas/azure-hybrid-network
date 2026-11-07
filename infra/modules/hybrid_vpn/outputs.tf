output "gateway_id" {
  description = "VPN gateway ID."
  value       = azurerm_virtual_network_gateway.this.id
}

output "gateway_public_ip" {
  description = "VPN gateway public IP."
  value       = azurerm_public_ip.gateway.ip_address
}

output "connection_id" {
  description = "Site-to-site connection ID."
  value       = azurerm_virtual_network_gateway_connection.s2s.id
}

output "sku" {
  description = "Gateway SKU."
  value       = azurerm_virtual_network_gateway.this.sku
}
