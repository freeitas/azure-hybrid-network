variable "name" {
  description = "Virtual network name."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the network resources."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "address_space" {
  description = "Virtual network address space."
  type        = list(string)
}

variable "subnets" {
  description = "Subnets keyed by name. Set nsg_enabled to link the shared NSG. Azure forbids an NSG on GatewaySubnet."
  type = map(object({
    address_prefix                  = string
    nsg_enabled                     = optional(bool, false)
    delegation                      = optional(string)
    default_outbound_access_enabled = optional(bool, false)
  }))
}

variable "nsg_name" {
  description = "Name of the network security group."
  type        = string
}

variable "nsg_rules" {
  description = "Inbound rules for the NSG, keyed by rule name. Azure's implicit DenyAllInBound applies to everything else."
  type = map(object({
    priority                = number
    protocol                = string
    source_address_prefixes = list(string)
    destination_port_ranges = list(string)
    access                  = optional(string, "Allow")
  }))
  default = {}
}

variable "tags" {
  description = "Tags for resources that support them. Subnets and peerings do not."
  type        = map(string)
}
