output "front_door_endpoints" {
  description = "Public hostname of each published site."
  value       = module.front_door.endpoint_hostnames
}

output "vm_private_ips" {
  description = "Private IP of each VM."
  value       = { for name, vm in module.vm : name => vm.private_ip_address }
}

output "key_vault_name" {
  description = "Key Vault holding the VM passwords and VPN shared key."
  value       = azurerm_key_vault.lab.name
}

output "vpn_gateway_public_ip" {
  description = "VPN gateway public IP, or null when the VPN is disabled."
  value       = one(module.hybrid_vpn[*].gateway_public_ip)
}

output "storage_accounts" {
  description = "Storage account names."
  value = {
    blob  = module.storage_blob.name
    files = module.storage_files.name
  }
}
