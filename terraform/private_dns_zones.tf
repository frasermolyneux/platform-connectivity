resource "azurerm_private_dns_zone" "zones" {
  for_each = toset(local.private_link_zones)

  name                = each.value
  resource_group_name = azurerm_resource_group.dns.name
  tags                = var.tags
}
