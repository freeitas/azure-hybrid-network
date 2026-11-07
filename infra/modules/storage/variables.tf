variable "name" {
  description = "Storage account name, globally unique."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the account."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "public_access_enabled" {
  description = "Whether the public endpoint is reachable. Anonymous access is always off."
  type        = bool
}

variable "containers" {
  description = "Private blob containers to create."
  type        = set(string)
  default     = []
}

variable "file_shares" {
  description = "File shares to create, as name => quota in GiB."
  type        = map(number)
  default     = {}
}

variable "cors_allowed_origins" {
  description = "Origins allowed to call the Blob service from a browser. Empty adds no CORS rule."
  type        = list(string)
  default     = []
}

variable "private_endpoint" {
  description = "Private endpoint settings. Null creates none."
  type = object({
    name                = string
    subnet_id           = string
    subresource         = string
    private_dns_zone_id = string
  })
  default = null
}

variable "sas_max_lifetime" {
  description = "Longest allowed account SAS lifetime, as DD.HH:MM:SS. Longer tokens are rejected."
  type        = string
  default     = "01.00:00:00"
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
}
