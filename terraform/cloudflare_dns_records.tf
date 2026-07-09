# Cloudflare DNS records for Cloudflare-managed zones (dns_provider == "cloudflare").
# One resource per record type keeps each for_each map homogeneous. Records owned by
# other stacks (e.g. platform-notifications ACS records) are carved out during
# conversion (scripts/Convert-CloudflareZones.ps1) and never appear here.

resource "cloudflare_dns_record" "a" {
  for_each = local.cf_a_records

  zone_id = each.value.zone_id
  name    = each.value.name
  type    = "A"
  ttl     = each.value.ttl
  content = each.value.content
  proxied = each.value.proxied
}

resource "cloudflare_dns_record" "aaaa" {
  for_each = local.cf_aaaa_records

  zone_id = each.value.zone_id
  name    = each.value.name
  type    = "AAAA"
  ttl     = each.value.ttl
  content = each.value.content
  proxied = each.value.proxied
}

resource "cloudflare_dns_record" "cname" {
  for_each = local.cf_cname_records

  zone_id = each.value.zone_id
  name    = each.value.name
  type    = "CNAME"
  ttl     = each.value.ttl
  content = each.value.content
  proxied = each.value.proxied
}

resource "cloudflare_dns_record" "mx" {
  for_each = local.cf_mx_records

  zone_id  = each.value.zone_id
  name     = each.value.name
  type     = "MX"
  ttl      = each.value.ttl
  content  = each.value.content
  priority = each.value.priority
}

resource "cloudflare_dns_record" "txt" {
  for_each = local.cf_txt_records

  zone_id = each.value.zone_id
  name    = each.value.name
  type    = "TXT"
  ttl     = each.value.ttl
  content = each.value.content
}

resource "cloudflare_dns_record" "srv" {
  for_each = local.cf_srv_records

  zone_id = each.value.zone_id
  name    = each.value.name
  type    = "SRV"
  ttl     = each.value.ttl
  data    = each.value.data
}
