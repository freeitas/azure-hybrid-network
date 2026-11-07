output "id" {
  description = "Virtual network ID."
  value       = azurerm_virtual_network.this.id
}

output "name" {
  description = "Virtual network name."
  value       = azurerm_virtual_network.this.name
}

output "address_space" {
  description = "Virtual network address space."
  value       = azurerm_virtual_network.this.address_space
}

output "subnet_ids" {
  description = "Subnet IDs keyed by subnet name."
  value       = { for name, subnet in azurerm_subnet.this : name => subnet.id }
}

output "nsg_name" {
  description = "Network security group name."
  value       = azurerm_network_security_group.this.name
}

output "nsg_subnet_names" {
  description = "Names of the subnets linked to the NSG."
  value       = keys(azurerm_subnet_network_security_group_association.this)
}

output "nsg_rules" {
  description = "NSG rules as configured, for policy assertions in tests."
  value       = var.nsg_rules
}
