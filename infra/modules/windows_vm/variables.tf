variable "name" {
  description = "VM name, also used as the computer name (15 characters at most)."
  type        = string

  validation {
    condition     = length(var.name) <= 15
    error_message = "Windows computer names cannot exceed 15 characters."
  }
}

variable "resource_group_name" {
  description = "Resource group for the VM."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "subnet_id" {
  description = "Subnet for the NIC. Traffic is filtered by the subnet NSG; the NIC has none."
  type        = string
}

variable "size" {
  description = "VM size."
  type        = string
}

variable "admin_username" {
  description = "Local administrator username."
  type        = string
}

variable "admin_password" {
  description = "Local administrator password."
  type        = string
  sensitive   = true
}

variable "image_version" {
  description = "Windows Server 2025 Azure Edition image version."
  type        = string
}

variable "public_ip_dns_label" {
  description = "DNS label for a public IP. Null creates no public IP."
  type        = string
  default     = null
}

variable "ip_forwarding_enabled" {
  description = "Allow the NIC to route traffic for other addresses. Required by the simulated on-premises firewall."
  type        = bool
  default     = false
}

variable "private_ip_address" {
  description = "Static private IP. Null uses dynamic allocation."
  type        = string
  default     = null
}

variable "shutdown_time" {
  description = "Daily auto-shutdown time as HHMM."
  type        = string
}

variable "shutdown_timezone" {
  description = "Windows time zone name for the auto-shutdown."
  type        = string
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
}
