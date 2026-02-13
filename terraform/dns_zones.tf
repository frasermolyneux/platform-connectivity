resource "azurerm_dns_zone" "zones" {
  for_each = local.dns_zones

  name                = each.value.name
  resource_group_name = azurerm_resource_group.dns.name
  tags                = var.tags
}
