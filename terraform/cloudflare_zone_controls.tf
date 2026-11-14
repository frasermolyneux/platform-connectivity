locals {
  cloudflare_bot_fight_zones = {
    for zone_key, zone in local.managed_cloudflare_zones :
    zone_key => zone if try(zone.bot_fight_mode, null) != null
  }

  cloudflare_managed_waf_ruleset_ids = {
    free = "77454fe2d30c4220b5701f6fdfb893ba"
    pro  = "efb7b8c949ac4650a09736fc376e9aee"
  }

  cloudflare_zone_rulesets = merge({}, [
    for zone_key, zone in local.managed_cloudflare_zones : {
      for phase, ruleset in merge(
        length(try(zone.managed_waf_hostnames, [])) == 0 ? {} : {
          http_request_firewall_managed = {
            name        = "Terraform-managed WAF"
            description = "Managed protection for declared HTTP services"
            rules = [{
              ref         = "execute_managed_waf"
              description = "Execute the plan-appropriate Cloudflare managed ruleset"
              action      = "execute"
              enabled     = true
              expression  = "http.host in {${join(" ", [for hostname in zone.managed_waf_hostnames : jsonencode(hostname)])}}"
              action_parameters = {
                id = local.cloudflare_managed_waf_ruleset_ids[try(zone.plan_profile, "free")]
              }
            }]
          }
        },
        try(zone.rulesets, {})
      ) :
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
data "cloudflare_bot_management" "existing" {
  for_each = local.cloudflare_bot_fight_zones

  zone_id = cloudflare_zone.managed[each.key].id
}

resource "cloudflare_bot_management" "managed" {
  for_each = local.cloudflare_bot_fight_zones

  zone_id    = cloudflare_zone.managed[each.key].id
  fight_mode = each.value.bot_fight_mode

  # The provider defaults these to false; retain the zone's existing preferences.
  ai_bots_migration_opt_out = data.cloudflare_bot_management.existing[each.key].ai_bots_migration_opt_out
  is_robots_txt_managed     = data.cloudflare_bot_management.existing[each.key].is_robots_txt_managed
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

moved {
  from = cloudflare_page_rule.managed["xtremeidiots.com/tcadmin"]
  to   = cloudflare_page_rule.retired_tcadmin[0]
}

resource "cloudflare_page_rule" "retired_tcadmin" {
  count = 0

  zone_id  = ""
  target   = ""
  priority = 1
  status   = "disabled"
  actions  = {}
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
