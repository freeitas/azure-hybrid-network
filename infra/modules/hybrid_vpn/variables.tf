variable "gateway_name" {
  description = "VPN gateway name."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the VPN resources."
  type        = string
}

variable "location" {
  description = "Azure region of the gateway's VNet."
  type        = string
}

variable "gateway_subnet_id" {
  description = "ID of the subnet named GatewaySubnet."
  type        = string
}

variable "sku" {
  description = "Gateway SKU. New non-AZ SKUs can no longer be created."
  type        = string
  default     = "VpnGw1AZ"
}

variable "p2s_address_pool" {
  description = "Client address pool for point-to-site. Must not overlap any connected network."
  type        = string
}

variable "tenant_id" {
  description = "Entra tenant used for point-to-site sign-in."
  type        = string
}

variable "onprem_gateway_ip" {
  description = "Public IP of the simulated on-premises firewall."
  type        = string
}

variable "onprem_address_spaces" {
  description = "Address spaces reachable through the on-premises firewall."
  type        = list(string)
}

variable "shared_key" {
  description = "Site-to-site pre-shared key."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
}
