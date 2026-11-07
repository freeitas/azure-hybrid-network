output "id" {
  description = "Web app ID."
  value       = azurerm_linux_web_app.this.id
}

output "default_hostname" {
  description = "Default hostname of the web app."
  value       = azurerm_linux_web_app.this.default_hostname
}

output "principal_id" {
  description = "System-assigned identity principal ID."
  value       = azurerm_linux_web_app.this.identity[0].principal_id
}
