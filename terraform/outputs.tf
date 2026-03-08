output "dns_resource_group_name" {
  value = azurerm_resource_group.dns.name
}

output "dns_zones" {
  value = {
    for key, zone in azurerm_dns_zone.zones : zone.name => {
      id                  = zone.id
      name                = zone.name
      resource_group_name = zone.resource_group_name
      name_servers        = zone.name_servers
      dns_provider        = try(local.dns_zones[key].dns_provider, "azure")
    }
  }
}
