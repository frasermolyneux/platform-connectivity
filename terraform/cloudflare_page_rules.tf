locals {
  preserved_page_rule_zones = {
    for key, zone in local.cloudflare_zones_to_adopt : key => zone
    if try(zone.preserve_page_rules, false)
  }
  preserved_page_rules = merge([
    for zone_key, zone in local.preserved_page_rule_zones : {
      for rule_key, rule in zone.page_rules :
      "${zone_key}|${rule_key}" => merge(rule, {
        zone_key = zone_key
        rule_key = rule_key
      })
    }
  ]...)
}

data "external" "preserved_page_rules" {
  for_each = local.preserved_page_rule_zones

  program = ["python3", "${path.module}/scripts/find_preserved_page_rules.py"]
  query = {
    zone_id = data.cloudflare_zone.adopt[each.key].zone_id
    rules   = jsonencode(each.value.page_rules)
  }
}

import {
  for_each = local.preserved_page_rules
  to       = cloudflare_page_rule.preserved[each.key]
  id       = "${data.cloudflare_zone.adopt[each.value.zone_key].zone_id}/${data.external.preserved_page_rules[each.value.zone_key].result[each.value.rule_key]}"
}

resource "cloudflare_page_rule" "preserved" {
  for_each = local.preserved_page_rules

  zone_id  = cloudflare_zone.managed[each.value.zone_key].id
  target   = each.value.target
  priority = each.value.priority
  status   = each.value.status
  actions  = each.value.actions

  lifecycle {
    prevent_destroy = true
  }
}
