# Subdomain delegation: Cloudflare parent zone -> Azure DNS child zone.
#
# Driven by var.dns_delegations (empty by default, so nothing is created yet).
# For each delegation an Azure DNS child zone is created and NS records are added
# to the Cloudflare parent zone pointing at the child zone's name servers, making
# Azure authoritative for the delegated subdomain.
resource "azurerm_dns_zone" "delegated" {
  for_each = local.delegations

  name                = each.key
  resource_group_name = azurerm_resource_group.dns.name
  tags                = var.tags
}

resource "cloudflare_dns_record" "delegation_ns" {
  for_each = local.delegation_ns

  zone_id = local.cloudflare_zone_ids[each.value.parent_zone]
  name    = each.value.subdomain
  type    = "NS"
  ttl     = 3600
  content = azurerm_dns_zone.delegated[each.value.delegation].name_servers[each.value.index]

  lifecycle {
    precondition {
      condition     = contains(keys(local.cloudflare_zone_ids), each.value.parent_zone)
      error_message = "dns_delegations parent_zone '${each.value.parent_zone}' is not a Cloudflare-managed zone in terraform/zones/."
    }
  }
}
