data "cloudflare_ruleset" "existing_custom_firewall" {
  for_each = {
    for key, zone in local.cloudflare_zones_to_adopt : key => zone
    if try(zone.waf_preserve_existing, false) && try(zone.waf_custom_rules_enabled, true) && length(try(local.cf_waf_ruleset_ids[key], [])) == 1
  }

  zone_id = data.cloudflare_zone.adopt[each.key].zone_id
  id      = local.cf_waf_ruleset_ids[each.key][0]
}

resource "cloudflare_ruleset" "zone_custom_firewall" {
  for_each = {
    for key, zone in local.managed_cloudflare_zones : key => zone
    if try(zone.waf_custom_rules_enabled, true)
  }

  zone_id     = cloudflare_zone.managed[each.key].id
  name        = try(each.value.waf_custom_ruleset.name, "Terraform-managed custom firewall rules")
  description = try(each.value.waf_custom_ruleset.description, "Shared Free-plan-compatible protection for common automated probes")
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  lifecycle {
    precondition {
      condition     = length(try(local.cf_waf_ruleset_ids[each.key], [])) <= 1
      error_message = "Zone ${each.value.name} has more than one http_request_firewall_custom entrypoint ruleset; resolve to a single ruleset before adoption so it can be imported rather than recreated."
    }
    precondition {
      condition = !try(each.value.adopt_existing, false) || (
        length(try(local.cf_waf_ruleset_ids[each.key], [])) == 1
      )
      error_message = "Adopted zone ${each.value.name} must have exactly one custom-firewall entrypoint; refusing to create one implicitly or guess among ambiguous rulesets."
    }
    precondition {
      condition = !try(each.value.adopt_existing, false) || (
        try(each.value.waf_preserve_existing, false) && try(
          length(local.cf_waf_ruleset_ids[each.key]) == 1 &&
          data.cloudflare_ruleset.existing_custom_firewall[each.key].name == each.value.waf_custom_ruleset.name &&
          data.cloudflare_ruleset.existing_custom_firewall[each.key].description == each.value.waf_custom_ruleset.description &&
          length(data.cloudflare_ruleset.existing_custom_firewall[each.key].rules) == length(each.value.waf_custom_ruleset.rules) &&
          alltrue([
            for index, expected in each.value.waf_custom_ruleset.rules : (
              data.cloudflare_ruleset.existing_custom_firewall[each.key].rules[index].action == expected.action &&
              data.cloudflare_ruleset.existing_custom_firewall[each.key].rules[index].description == expected.description &&
              data.cloudflare_ruleset.existing_custom_firewall[each.key].rules[index].expression == expected.expression &&
              data.cloudflare_ruleset.existing_custom_firewall[each.key].rules[index].enabled == expected.enabled &&
              data.cloudflare_ruleset.existing_custom_firewall[each.key].rules[index].ref == try(expected.ref, data.cloudflare_ruleset.existing_custom_firewall[each.key].rules[index].id) &&
              jsonencode(try(data.cloudflare_ruleset.existing_custom_firewall[each.key].rules[index].action_parameters.products, null)) == jsonencode(try(expected.action_parameters.products, null)) &&
              jsonencode(try(data.cloudflare_ruleset.existing_custom_firewall[each.key].rules[index].action_parameters.response, null)) == jsonencode(try(expected.action_parameters.response, null)) &&
              try(data.cloudflare_ruleset.existing_custom_firewall[each.key].rules[index].logging.enabled, null) == try(expected.logging.enabled, null) &&
              try(data.cloudflare_ruleset.existing_custom_firewall[each.key].rules[index].ratelimit, null) == null &&
              try(data.cloudflare_ruleset.existing_custom_firewall[each.key].rules[index].exposed_credential_check, null) == null &&
              alltrue([
                for key in keys(expected) :
                contains(["ref", "description", "expression", "action", "enabled", "action_parameters", "logging"], key)
              ]) &&
              alltrue([
                for key in try(keys(expected.action_parameters), []) :
                contains(["products", "response"], key)
              ]) &&
              alltrue(try([for key in keys(expected.logging) : key == "enabled"], [])) &&
              alltrue(try([
                for key, value in data.cloudflare_ruleset.existing_custom_firewall[each.key].rules[index].action_parameters :
                value == null || contains(["products", "response"], key)
              ], []))
            )
          ]),
          false
        )
      )
      error_message = "The existing custom-firewall entrypoint for ${each.value.name} differs from its reviewed preservation snapshot or cannot be read. Stop and reconcile the entire phase before adoption."
    }
  }

  rules = try([
    for index, rule in each.value.waf_custom_ruleset.rules : merge(rule, {
      ref = try(rule.ref, data.cloudflare_ruleset.existing_custom_firewall[each.key].rules[index].ref, null)
    })
    ], [
    {
      ref         = "block_sensitive_file_probes"
      description = "Block requests for common sensitive files and directories"
      expression  = "(lower(http.request.uri.path) eq \"/.env\") or starts_with(lower(http.request.uri.path), \"/.env.\") or (lower(http.request.uri.path) eq \"/.git\") or starts_with(lower(http.request.uri.path), \"/.git/\") or (lower(http.request.uri.path) eq \"/.aws/credentials\") or (lower(http.request.uri.path) eq \"/appsettings.json\") or starts_with(lower(http.request.uri.path), \"/appsettings.\") or (lower(http.request.uri.path) eq \"/web.config\")"
      action      = "block"
    },
    {
      ref         = "challenge_common_cms_probes"
      description = "Challenge likely automated probes for common CMS administration endpoints"
      expression  = "(lower(http.request.uri.path) eq \"/wp-login.php\") or (lower(http.request.uri.path) eq \"/xmlrpc.php\") or (lower(http.request.uri.path) eq \"/wp-admin\") or starts_with(lower(http.request.uri.path), \"/wp-admin/\")"
      action      = "managed_challenge"
    }
  ])
}
