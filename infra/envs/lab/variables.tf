variable "owner" {
  description = "Value of the owner tag."
  type        = string
}

variable "admin_username" {
  description = "Local administrator username for every VM."
  type        = string

  validation {
    condition     = !contains(["admin", "administrator", "root", "guest", "user"], lower(var.admin_username))
    error_message = "Azure rejects common administrator usernames; choose another."
  }
}

variable "admin_source_cidr" {
  description = "Optional public CIDR allowed to RDP to vm-fw-001, for setup before the VPN exists. Null keeps RDP reachable over VPN only."
  type        = string
  default     = null

  validation {
    condition     = var.admin_source_cidr == null ? true : (can(cidrhost(var.admin_source_cidr, 0)) && tonumber(split("/", var.admin_source_cidr)[1]) >= 24)
    error_message = "admin_source_cidr must be a valid CIDR no wider than /24, so RDP is never open to the internet."
  }
}

variable "vpn_enabled" {
  description = "Create the VPN gateway and tunnel. The gateway is the largest recurring cost, so disable it between study sessions."
  type        = bool
  default     = true
}

variable "vpn_transit_enabled" {
  description = "Let the Canada VNet use the Austria gateway. To turn the VPN off, first apply with this false, then apply with vpn_enabled false: Azure refuses to drop transit while the other side still uses it."
  type        = bool
  default     = true
}

variable "p2s_address_pool" {
  description = "Client address pool for point-to-site VPN."
  type        = string
  default     = "172.16.201.0/24"

  validation {
    condition     = can(cidrhost(var.p2s_address_pool, 0)) && endswith(var.p2s_address_pool, "/24")
    error_message = "p2s_address_pool must be a /24, because the IIS admin exemption matches its first three octets."
  }
}

variable "vm_size" {
  description = "Size of every VM."
  type        = string
  default     = "Standard_B2ls_v2"
}

variable "image_version" {
  description = "Windows Server image version. Pin one from `az vm image list --all` for repeatable rebuilds."
  type        = string
  default     = "latest"
}

variable "shutdown_time" {
  description = "Daily VM auto-shutdown time as HHMM."
  type        = string
  default     = "2200"
}

variable "shutdown_timezone" {
  description = "Windows time zone name for the auto-shutdown."
  type        = string
  default     = "UTC"
}

variable "url_rewrite_msi_url" {
  description = "Download URL of the IIS URL Rewrite installer."
  type        = string
  default     = "https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi"
}

variable "url_rewrite_msi_sha256" {
  description = "Expected SHA-256 of the URL Rewrite installer."
  type        = string
  default     = "37342FF2F585F263F34F48E9DE59EB1051D61015A8E967DBDE4075716230A32A"
}

variable "app_packages" {
  description = "Optional application ZIP per VM, keyed by VM name, with its SHA-256 hash. URL-encode spaces. Sensitive because a private blob URL carries a SAS."
  type = map(object({
    url    = string
    sha256 = string
  }))
  default   = {}
  sensitive = true
}

variable "alert_email" {
  description = "Address that receives budget and VPN alerts."
  type        = string
}

variable "monthly_budget" {
  description = "Monthly budget per resource group, in the billing currency."
  type        = number
  default     = 150
}

variable "budget_start_date" {
  description = "First day of the budget's first month, in RFC 3339 format. It cannot be in the past when the budget is created."
  type        = string
}
