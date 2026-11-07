variable "vault_name" {
  description = "Recovery Services vault name."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the vault."
  type        = string
}

variable "location" {
  description = "Azure region. Must match every protected VM and storage account."
  type        = string
}

variable "vm_ids" {
  description = "VMs to protect, keyed by name."
  type        = map(string)
  default     = {}
}

variable "file_shares" {
  description = "File shares to protect, keyed by a static name."
  type = map(object({
    storage_account_id = string
    share_name         = string
  }))
  default = {}
}

variable "retention_days" {
  description = "Daily recovery points to keep."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
}
