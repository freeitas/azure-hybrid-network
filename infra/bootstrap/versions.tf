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
  }
}

provider "azurerm" {
  resource_provider_registrations = "none"
  resource_providers_to_register  = ["Microsoft.Storage"]

  features {
    # The account has shared keys disabled; everything here goes through ARM.
    storage {
      data_plane_available = false
    }
  }
}
