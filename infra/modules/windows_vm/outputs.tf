output "id" {
  description = "VM ID."
  value       = azurerm_windows_virtual_machine.this.id
}

output "private_ip_address" {
  description = "Private IP of the NIC."
  value       = azurerm_network_interface.this.private_ip_address
}

output "public_ip_address" {
  description = "Public IP, or null when the VM has none."
  value       = one(azurerm_public_ip.this[*].ip_address)
}

output "public_fqdn" {
  description = "Public DNS name, or null when the VM has no public IP."
  value       = one(azurerm_public_ip.this[*].fqdn)
}

output "ip_forwarding_enabled" {
  description = "Whether the NIC forwards traffic."
  value       = azurerm_network_interface.this.ip_forwarding_enabled
}

output "os_disk_type" {
  description = "OS disk storage type."
  value       = azurerm_windows_virtual_machine.this.os_disk[0].storage_account_type
}

output "has_public_ip" {
  description = "Whether the VM has a public IP."
  value       = var.public_ip_dns_label != null
}
