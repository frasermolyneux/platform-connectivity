terraform {
  required_version = ">= 1.15.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.80.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.21.0"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  subscription_id = var.subscription_id

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  storage_use_azuread = true
}

provider "cloudflare" {
  # Environments without Cloudflare zones (dev has no dns_zones_path) do not receive
  # the CLOUDFLARE_API_KEY secret, so the token is empty. Supply a valid-format
  # placeholder so the provider's client-side format check passes; it is never used
  # because no Cloudflare resources or data sources are evaluated there.
  api_token = var.cloudflare_api_token != "" ? var.cloudflare_api_token : "placeholder_unused_token"
}
