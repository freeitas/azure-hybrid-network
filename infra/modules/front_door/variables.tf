variable "profile_id" {
  description = "Front Door profile ID."
  type        = string
}

variable "sites" {
  description = "Published sites keyed by short name. VM origins have no certificate, so origin_protocol is Http for them and Https for web apps."
  type = map(object({
    host_name       = string
    origin_protocol = string
  }))

  validation {
    condition     = alltrue([for site in values(var.sites) : contains(["Http", "Https"], site.origin_protocol)])
    error_message = "origin_protocol must be Http or Https."
  }
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
}
