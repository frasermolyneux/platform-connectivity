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

  cloudflare_page_rules_to_adopt = {
    for key, rule in local.cloudflare_page_rules : key => rule
    if contains(keys(local.cloudflare_zones_to_adopt), rule.zone_key)
  }
}

data "external" "cloudflare_page_rule" {
  for_each = local.cloudflare_page_rules_to_adopt

  program = ["python3", "${path.module}/scripts/find_page_rule.py"]
  query = {
    zone_id       = data.cloudflare_zone.adopt[each.value.zone_key].zone_id
    target        = each.value.target
    actions       = jsonencode(each.value.actions)
    priority      = tostring(each.value.priority)
    status        = each.value.status
    require_match = "false"
  }
}

import {
  for_each = {
    for key, rule in local.cloudflare_page_rules_to_adopt : key => rule
    if data.external.cloudflare_page_rule[key].result.id != ""
  }
  to = cloudflare_page_rule.managed[each.key]
  id = "${data.cloudflare_zone.adopt[each.value.zone_key].zone_id}/${data.external.cloudflare_page_rule[each.key].result.id}"
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

data "cloudflare_ruleset" "existing_zone_ruleset" {
  for_each = local.cf_zone_ruleset_discovery

  zone_id = data.cloudflare_zone.adopt[each.value.zone_key].zone_id
  id      = local.cf_zone_ruleset_ids[each.key][0]
}

import {
  for_each = local.cf_zone_ruleset_imports
  to       = cloudflare_ruleset.zone_configured[each.key]
  id       = each.value
}

resource "cloudflare_ruleset" "zone_configured" {
  for_each = local.cloudflare_zone_rulesets

  zone_id     = cloudflare_zone.managed[each.value.zone_key].id
  name        = each.value.name
  description = try(each.value.description, null)
  kind        = "zone"
  phase       = each.value.phase
  rules = [
    for index, rule in each.value.rules : merge(rule, {
      ref = try(rule.ref, data.cloudflare_ruleset.existing_zone_ruleset[each.key].rules[index].ref, null)
    })
  ]

  lifecycle {
    precondition {
      condition = !contains(
        ["http_config_settings", "http_request_firewall_custom"],
        each.value.phase
      )
      error_message = "The http_config_settings phase is owned by the status edge stack, and the custom-firewall phase uses its dedicated preservation resource."
    }
    precondition {
      condition = !try(
        local.cloudflare_zones_to_adopt[each.value.zone_key].adopt_existing,
        false
      ) || length(try(local.cf_zone_ruleset_ids[each.key], [])) <= 1
      error_message = "Adopted zone ${each.value.zone_key} has ambiguous ${each.value.phase} entrypoints; resolve to at most one before managing this ruleset."
    }
    precondition {
      condition = !contains(keys(local.cloudflare_zones_to_adopt), each.value.zone_key) || length(try(
        local.cf_zone_ruleset_ids[each.key],
        []
      )) == 0 || try(data.external.cloudflare_ruleset_snapshot[each.key].result.matches == "true", false)
      error_message = "Adopted zone ${each.value.zone_key} ${each.value.phase} ruleset differs from its reviewed snapshot at ${try(data.external.cloudflare_ruleset_snapshot[each.key].result.differences, "unknown")}. Re-inventory and reconcile before adoption."
    }
  }
}
