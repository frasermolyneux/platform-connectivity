# Import blocks for existing Azure resources deployed by Bicep.
# These will run on the first terraform apply to adopt resources into state.
# Once imported successfully, these blocks can be removed.

locals {
  resource_group_id = "/subscriptions/${var.subscription_id}/resourceGroups/${local.dns_resource_group_name}"
}

# --- Resource Group ---

import {
  to = azurerm_resource_group.dns
  id = local.resource_group_id
}

# --- Public DNS Zones ---

import {
  for_each = local.dns_zones
  to       = azurerm_dns_zone.zones[each.key]
  id       = "${local.resource_group_id}/providers/Microsoft.Network/dnsZones/${each.value.name}"
}

# --- A Records ---

import {
  for_each = local.a_records
  to       = azurerm_dns_a_record.records[each.key]
  id       = "${local.resource_group_id}/providers/Microsoft.Network/dnsZones/${each.value.zone_name}/A/${each.value.name}"
}

# --- AAAA Records ---

import {
  for_each = local.aaaa_records
  to       = azurerm_dns_aaaa_record.records[each.key]
  id       = "${local.resource_group_id}/providers/Microsoft.Network/dnsZones/${each.value.zone_name}/AAAA/${each.value.name}"
}

# --- CNAME Records ---

import {
  for_each = local.cname_records
  to       = azurerm_dns_cname_record.records[each.key]
  id       = "${local.resource_group_id}/providers/Microsoft.Network/dnsZones/${each.value.zone_name}/CNAME/${each.value.name}"
}

# --- MX Records ---

import {
  for_each = local.mx_records
  to       = azurerm_dns_mx_record.records[each.key]
  id       = "${local.resource_group_id}/providers/Microsoft.Network/dnsZones/${each.value.zone_name}/MX/${each.value.name}"
}

# --- TXT Records ---

import {
  for_each = local.txt_records
  to       = azurerm_dns_txt_record.records[each.key]
  id       = "${local.resource_group_id}/providers/Microsoft.Network/dnsZones/${each.value.zone_name}/TXT/${each.value.name}"
}

# --- SRV Records ---

import {
  for_each = { for k, v in local.srv_records : k => v if !v.skip_import }
  to       = azurerm_dns_srv_record.records[each.key]
  id       = "${local.resource_group_id}/providers/Microsoft.Network/dnsZones/${each.value.zone_name}/SRV/${each.value.name}"
}

# --- Private Link DNS Zones ---

import {
  for_each = toset(local.private_link_zones)
  to       = azurerm_private_dns_zone.zones[each.key]
  id       = "${local.resource_group_id}/providers/Microsoft.Network/privateDnsZones/${each.value}"
}
