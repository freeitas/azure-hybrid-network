variable "location" {
  description = "Azure region for the Terraform state storage."
  type        = string
  default     = "austriaeast"
}

variable "owner" {
  description = "Value of the owner tag."
  type        = string
}

variable "ci_principal_ids" {
  description = "Object IDs of the CI identities that need state access, keyed by a static name."
  type        = map(string)
  default     = {}
}

variable "allowed_ips" {
  description = "Public IPv4 addresses or ranges allowed to reach the state account (no /31 or /32 suffix). Empty leaves the endpoint reachable, protected by Entra ID only, which hosted CI runners need."
  type        = list(string)
  default     = []
}
