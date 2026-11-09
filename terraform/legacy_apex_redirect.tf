locals {
  legacy_apex_redirect_zones = {
    for key, zone in local.active_cloudflare_zones : key => zone
    if try(zone.legacy_apex_redirect_disabled, false)
  }
}

resource "cloudflare_page_rule" "legacy_apex_redirect" {
  for_each = local.legacy_apex_redirect_zones

  zone_id  = local.cloudflare_zone_ids[each.value.name]
  target   = "https://${each.value.name}/*"
  priority = 1
  status   = "disabled"
  actions = {
    forwarding_url = {
      url         = "https://www.${each.value.name}/"
      status_code = 301
    }
  }

  lifecycle {
    prevent_destroy = true

    precondition {
      condition = (try(each.value.management, "external") == "external" || try(each.value.origin_tls_preserve_existing, false)) && alltrue([
        for hostname in [each.value.name, "www.${each.value.name}"] :
        contains(try(each.value.origin_tls_hostnames, []), hostname)
      ])
      error_message = "Legacy redirect retirement requires an external zone or an explicitly preserved existing origin TLS owner, with both canonical hostnames covered by strict origin TLS."
    }
  }
}
