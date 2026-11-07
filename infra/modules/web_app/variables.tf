variable "plan_name" {
  description = "App Service plan name."
  type        = string
}

variable "app_name" {
  description = "Web app name, globally unique."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the plan and app."
  type        = string
}

variable "location" {
  description = "Azure region. Must match the integration subnet's VNet."
  type        = string
}

variable "sku_name" {
  description = "App Service plan SKU."
  type        = string
  default     = "B1"
}

variable "node_version" {
  description = "Node.js runtime version."
  type        = string
  default     = "22-lts"
}

variable "startup_command" {
  description = "Optional startup command."
  type        = string
  default     = null
}

variable "integration_subnet_id" {
  description = "Subnet delegated to Microsoft.Web/serverFarms, for outbound VNet integration."
  type        = string
}

variable "front_door_id" {
  description = "Front Door profile resource GUID. Only requests carrying it are accepted."
  type        = string
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
}
