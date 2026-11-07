resource "azurerm_virtual_network" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                            = each.key
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = [each.value.address_prefix]
  default_outbound_access_enabled = each.value.default_outbound_access_enabled

  dynamic "delegation" {
    for_each = each.value.delegation == null ? [] : [each.value.delegation]

    content {
      name = "delegation"

      service_delegation {
        name = delegation.value
      }
    }
  }
}

resource "azurerm_network_security_group" "this" {
  name                = var.nsg_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_network_security_rule" "this" {
  for_each = var.nsg_rules

  name                        = each.key
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this.name
  direction                   = "Inbound"
  access                      = each.value.access
  priority                    = each.value.priority
  protocol                    = each.value.protocol
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_ranges     = each.value.destination_port_ranges

  # The list form rejects service tags, so a single value uses the singular form.
  source_address_prefix   = length(each.value.source_address_prefixes) == 1 ? each.value.source_address_prefixes[0] : null
  source_address_prefixes = length(each.value.source_address_prefixes) > 1 ? each.value.source_address_prefixes : null
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = { for name, subnet in var.subnets : name => subnet if subnet.nsg_enabled }

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this.id
}
