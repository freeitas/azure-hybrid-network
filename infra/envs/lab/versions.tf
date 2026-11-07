terraform {
  required_version = ">= 1.10.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
  }

  # Values come from backend.hcl, created from the bootstrap output.
  backend "azurerm" {}
}

provider "azurerm" {
  resource_provider_registrations = "none"
  resource_providers_to_register = [
    "Microsoft.Authorization",
    "Microsoft.Cdn",
    "Microsoft.Compute",
    "Microsoft.Consumption",
    "Microsoft.DataProtection",
    "Microsoft.DevTestLab",
    "Microsoft.Insights",
    "Microsoft.KeyVault",
    "Microsoft.Network",
    "Microsoft.OperationalInsights",
    "Microsoft.PolicyInsights",
    "Microsoft.RecoveryServices",
    "Microsoft.Storage",
    "Microsoft.Web",
  ]

  features {
    key_vault {
      # Purge protection is on, so a destroyed vault stays soft-deleted for its retention.
      purge_soft_delete_on_destroy = false
    }

    recovery_service {
      # This is a lab: `terraform destroy` must also remove its recovery points.
      purge_protected_items_from_vault_on_destroy          = true
      vm_backup_stop_protection_and_retain_data_on_destroy = false
    }

    storage {
      # One account has its public endpoint disabled; everything here goes through ARM.
      data_plane_available = false
    }
  }
}
