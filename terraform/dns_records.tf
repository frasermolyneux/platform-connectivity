resource "azurerm_dns_a_record" "records" {
  for_each = local.a_records

  name                = each.value.name
  zone_name           = azurerm_dns_zone.zones[each.value.zone_key].name
  resource_group_name = azurerm_resource_group.dns.name
  ttl                 = each.value.ttl
  records             = each.value.records
  tags                = var.tags
}

resource "azurerm_dns_aaaa_record" "records" {
  for_each = local.aaaa_records

  name                = each.value.name
  zone_name           = azurerm_dns_zone.zones[each.value.zone_key].name
  resource_group_name = azurerm_resource_group.dns.name
  ttl                 = each.value.ttl
  records             = each.value.records
  tags                = var.tags
}

resource "azurerm_dns_cname_record" "records" {
  for_each = local.cname_records

  name                = each.value.name
  zone_name           = azurerm_dns_zone.zones[each.value.zone_key].name
  resource_group_name = azurerm_resource_group.dns.name
  ttl                 = each.value.ttl
  record              = each.value.record
  tags                = var.tags
}

resource "azurerm_dns_mx_record" "records" {
  for_each = local.mx_records

  name                = each.value.name
  zone_name           = azurerm_dns_zone.zones[each.value.zone_key].name
  resource_group_name = azurerm_resource_group.dns.name
  ttl                 = each.value.ttl
  tags                = var.tags

  dynamic "record" {
    for_each = each.value.records
    content {
      preference = record.value.preference
      exchange   = record.value.exchange
    }
  }
}

resource "azurerm_dns_txt_record" "records" {
  for_each = local.txt_records

  name                = each.value.name
  zone_name           = azurerm_dns_zone.zones[each.value.zone_key].name
  resource_group_name = azurerm_resource_group.dns.name
  ttl                 = each.value.ttl
  tags                = var.tags

  dynamic "record" {
    for_each = each.value.records
    content {
      value = record.value
    }
  }
}

resource "azurerm_dns_srv_record" "records" {
  for_each = local.srv_records

  name                = each.value.name
  zone_name           = azurerm_dns_zone.zones[each.value.zone_key].name
  resource_group_name = azurerm_resource_group.dns.name
  ttl                 = each.value.ttl
  tags                = var.tags

  dynamic "record" {
    for_each = each.value.records
    content {
      priority = record.value.priority
      weight   = record.value.weight
      port     = record.value.port
      target   = record.value.target
    }
  }
}
