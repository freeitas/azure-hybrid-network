output "vault_id" {
  description = "Recovery Services vault ID."
  value       = azurerm_recovery_services_vault.this.id
}

output "location" {
  description = "Vault region."
  value       = azurerm_recovery_services_vault.this.location
}
