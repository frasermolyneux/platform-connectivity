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
  # Only the environment that manages Cloudflare zones (dns_zones_path set — i.e. prd)
  # uses the real token. Other environments (dev) have no Cloudflare resources, so use
  # a valid-format placeholder and ignore the CLOUDFLARE_API_KEY secret entirely — it
  # may be absent or malformed there and the provider validates the token format at
  # configuration time regardless of whether any Cloudflare resources exist.
  api_token = var.dns_zones_path != "" ? var.cloudflare_api_token : "placeholder_unused_token"
}
