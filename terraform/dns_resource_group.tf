resource "azurerm_resource_group" "dns" {
  name     = local.dns_resource_group_name
  location = var.location
  tags     = var.tags

  lifecycle {
    precondition {
      condition     = length(local.cloudflare_unsupported_dns_records) == 0
      error_message = "Unsupported Cloudflare DNS record types are configured: ${join(", ", local.cloudflare_unsupported_dns_records)}. Add explicit Terraform resource and import support before using these records."
    }

    precondition {
      condition = alltrue([
        for zone in values(local.managed_cloudflare_zones) :
        alltrue([
          for record in try(zone.records, []) :
          try(trimspace(record.key), "") != ""
        ])
      ])
      error_message = "Every DNS record in a Terraform-managed Cloudflare zone requires an explicit stable key."
    }
  }
}
