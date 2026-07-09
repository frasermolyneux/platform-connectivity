output "dns_resource_group_name" {
  value = azurerm_resource_group.dns.name
}

output "dns_zones" {
  value = merge(
    {
      for key, zone in azurerm_dns_zone.zones : zone.name => {
        id                  = zone.id
        name                = zone.name
        resource_group_name = zone.resource_group_name
        name_servers        = zone.name_servers
        dns_provider        = try(local.dns_zones[key].dns_provider, "azure")
      }
    },
    {
      for key, z in local.cloudflare_zones : z.name => {
        id                  = z.zone_id
        name                = z.name
        resource_group_name = null
        name_servers        = []
        dns_provider        = "cloudflare"
      } if !try(z.backup_to_azure, false)
    }
  )
}

output "delegated_zone_name_servers" {
  description = "Name servers for Azure DNS child zones created via var.dns_delegations."
  value       = { for k, z in azurerm_dns_zone.delegated : k => z.name_servers }
}
