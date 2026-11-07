resource "azurerm_public_ip" "this" {
  count = var.public_ip_dns_label == null ? 0 : 1

  name                = "pip-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = var.public_ip_dns_label
  tags                = var.tags
}

resource "azurerm_network_interface" "this" {
  name                  = "nic-${var.name}"
  resource_group_name   = var.resource_group_name
  location              = var.location
  ip_forwarding_enabled = var.ip_forwarding_enabled
  tags                  = var.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = var.private_ip_address == null ? "Dynamic" : "Static"
    private_ip_address            = var.private_ip_address
    public_ip_address_id          = one(azurerm_public_ip.this[*].id)
  }
}

resource "azurerm_windows_virtual_machine" "this" {
  name                  = var.name
  computer_name         = var.name
  resource_group_name   = var.resource_group_name
  location              = var.location
  size                  = var.size
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.this.id]

  # Trusted Launch and platform patching, both supported by this Gen2 image.
  secure_boot_enabled = true
  vtpm_enabled        = true
  patch_mode          = "AutomaticByPlatform"

  tags = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-azure-edition"
    version   = var.image_version
  }

  boot_diagnostics {}
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "this" {
  virtual_machine_id    = azurerm_windows_virtual_machine.this.id
  location              = var.location
  enabled               = true
  daily_recurrence_time = var.shutdown_time
  timezone              = var.shutdown_timezone
  tags                  = var.tags

  notification_settings {
    enabled = false
  }
}
