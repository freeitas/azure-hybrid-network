output "backend_config" {
  description = "Contents for infra/envs/lab/backend.hcl."
  value       = <<-EOT
    resource_group_name  = "${azurerm_resource_group.state.name}"
    storage_account_name = "${azurerm_storage_account.state.name}"
    container_name       = "${azurerm_storage_container.state.name}"
    key                  = "lab.tfstate"
    use_azuread_auth     = true
  EOT
}
