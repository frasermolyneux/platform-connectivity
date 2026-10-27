locals {
  legacy_apex_redirect_zones = {
    for key, zone in local.active_cloudflare_zones : key => zone
    if try(zone.legacy_apex_redirect_disabled, false)
  }
}

data "external" "legacy_apex_redirect" {
  for_each = local.legacy_apex_redirect_zones

  program = ["python3", "${path.module}/scripts/find_page_rule.py"]
  query = {
    zone_id     = local.cloudflare_zone_ids[each.value.name]
    target      = "https://${each.value.name}/*"
    url         = "https://www.${each.value.name}/"
    status_code = "301"
    priority    = "1"
  }
}

import {
  for_each = local.legacy_apex_redirect_zones
  to       = cloudflare_page_rule.legacy_apex_redirect[each.key]
  id       = "${local.cloudflare_zone_ids[each.value.name]}/${data.external.legacy_apex_redirect[each.key].result.id}"
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
      condition = try(each.value.management, "external") == "external" && alltrue([
        for hostname in [each.value.name, "www.${each.value.name}"] :
        contains(try(each.value.origin_tls_hostnames, []), hostname)
      ])
      error_message = "Legacy redirect retirement requires an external zone with both canonical hostnames covered by strict origin TLS."
    }
  }
}
