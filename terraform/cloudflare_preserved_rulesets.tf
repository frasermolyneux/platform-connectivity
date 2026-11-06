locals {
  preserved_ruleset_zones = {
    for key, zone in local.cloudflare_zones_to_adopt : key => zone
    if try(zone.preserve_rulesets, false)
  }
  preserved_rulesets = merge([
    for zone_key, zone in local.preserved_ruleset_zones : {
      for phase, snapshot in zone.preserved_rulesets :
      "${zone_key}|${phase}" => {
        zone_key = zone_key
        phase    = phase
        snapshot = snapshot
      }
    }
  ]...)
}

data "external" "preserved_rulesets" {
  for_each = local.preserved_ruleset_zones

  program = ["python3", "${path.module}/scripts/find_preserved_rulesets.py"]
  query = {
    zone_id  = data.cloudflare_zone.adopt[each.key].zone_id
    rulesets = jsonencode(each.value.preserved_rulesets)
  }
}

import {
  for_each = local.preserved_rulesets
  to       = cloudflare_ruleset.preserved[each.key]
  id       = "zones/${data.cloudflare_zone.adopt[each.value.zone_key].zone_id}/${data.external.preserved_rulesets[each.value.zone_key].result["${each.value.phase}_id"]}"
}

resource "cloudflare_ruleset" "preserved" {
  for_each = local.preserved_rulesets

  zone_id     = cloudflare_zone.managed[each.value.zone_key].id
  name        = each.value.snapshot.name
  description = each.value.snapshot.description
  kind        = "zone"
  phase       = each.value.phase
  rules       = jsondecode(data.external.preserved_rulesets[each.value.zone_key].result["${each.value.phase}_rules"])

  lifecycle {
    prevent_destroy = true
  }
}
