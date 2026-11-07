output "id" {
  description = "Storage account ID."
  value       = azurerm_storage_account.this.id
}

output "name" {
  description = "Storage account name."
  value       = azurerm_storage_account.this.name
}

output "public_network_access" {
  description = "Public endpoint state."
  value       = azurerm_storage_account.this.public_network_access
}

output "has_private_endpoint" {
  description = "Whether the account has a private endpoint."
  value       = var.private_endpoint != null
}
