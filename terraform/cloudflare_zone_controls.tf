locals {
  cloudflare_zone_rulesets = merge({}, [
    for zone_key, zone in local.managed_cloudflare_zones : {
      for phase, ruleset in try(zone.rulesets, {}) :
      "${zone_key}/${phase}" => merge(ruleset, {
        zone_key = zone_key
        phase    = phase
      })
    }
  ]...)

  cloudflare_page_rules = merge({}, [
    for zone_key, zone in local.managed_cloudflare_zones : {
      for rule_key, rule in try(zone.page_rules, {}) :
      "${zone_key}/${rule_key}" => merge(rule, {
        zone_key = zone_key
        rule_key = rule_key
      })
    }
  ]...)

}
resource "cloudflare_page_rule" "managed" {
  for_each = local.cloudflare_page_rules

  zone_id  = cloudflare_zone.managed[each.value.zone_key].id
  target   = each.value.target
  priority = each.value.priority
  status   = each.value.status
  actions  = each.value.actions

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_ruleset" "zone_configured" {
  for_each = local.cloudflare_zone_rulesets

  zone_id     = cloudflare_zone.managed[each.value.zone_key].id
  name        = each.value.name
  description = try(each.value.description, null)
  kind        = "zone"
  phase       = each.value.phase
  rules       = each.value.rules

  lifecycle {
    precondition {
      condition = !contains(
        ["http_config_settings", "http_request_firewall_custom"],
        each.value.phase
      )
      error_message = "The http_config_settings phase is owned by the status edge stack, and the custom-firewall phase has a dedicated managed resource."
    }
    precondition {
      condition = alltrue([
        for rule in each.value.rules : try(trimspace(rule.ref), "") != ""
      ])
      error_message = "Each configured ${each.value.phase} ruleset rule in ${each.value.zone_key} requires an explicit stable ref."
    }
  }
}
