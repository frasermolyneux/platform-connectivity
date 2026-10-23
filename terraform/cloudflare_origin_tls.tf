locals {
  cloudflare_origin_tls_requested_zones = {
    for key, zone in local.active_cloudflare_zones : key => zone
    if length(try(zone.origin_tls_hostnames, [])) > 0
  }
  cloudflare_origin_tls_zones = {
    for key, zone in local.cloudflare_origin_tls_requested_zones : key => zone
    if try(zone.management, "external") == "external"
  }
}

data "cloudflare_rulesets" "origin_tls" {
  for_each = local.cloudflare_origin_tls_zones

  zone_id = local.cloudflare_zone_ids[each.value.name]
}

resource "terraform_data" "origin_tls_owner" {
  for_each = local.cloudflare_origin_tls_requested_zones

  input = each.value.name

  lifecycle {
    prevent_destroy = true

    precondition {
      condition     = try(each.value.management, "external") == "external"
      error_message = "Hostname origin TLS overrides require an existing external zone. Terraform-managed zones already use the strict baseline; remove origin_tls_hostnames."
    }
  }
}

locals {
  cloudflare_origin_tls_imports = merge([
    for key, zone in local.cloudflare_origin_tls_zones : {
      for ruleset in data.cloudflare_rulesets.origin_tls[key].rulesets :
      key => "zones/${local.cloudflare_zone_ids[zone.name]}/${ruleset.id}"
      if ruleset.phase == "http_config_settings" &&
      startswith(ruleset.name, "origin-tls-") &&
      ruleset.name == "origin-tls-${terraform_data.origin_tls_owner[key].id}"
    }
  ]...)
}

import {
  for_each = local.cloudflare_origin_tls_imports
  to       = cloudflare_ruleset.origin_tls[each.key]
  id       = each.value
}

resource "cloudflare_ruleset" "origin_tls" {
  for_each = local.cloudflare_origin_tls_zones

  zone_id     = local.cloudflare_zone_ids[each.value.name]
  name        = "origin-tls-${terraform_data.origin_tls_owner[each.key].id}"
  description = "Strict origin TLS only for explicitly selected proxied hostnames"
  kind        = "zone"
  phase       = "http_config_settings"

  rules = [
    for hostname in each.value.origin_tls_hostnames : {
      ref         = "origin_strict_${replace(hostname, ".", "_")}"
      description = "Validate the origin certificate for ${hostname}"
      expression  = "http.host eq \"${hostname}\""
      action      = "set_config"
      enabled     = true
      action_parameters = {
        ssl = "strict"
      }
    }
  ]

  lifecycle {
    prevent_destroy = true

    precondition {
      condition = alltrue([
        for hostname in each.value.origin_tls_hostnames :
        !strcontains(hostname, "*") && contains([
          for record in each.value.records :
          record.name == "@" ? each.value.name : "${record.name}.${each.value.name}"
          if try(record.proxied, false)
        ], hostname)
      ])
      error_message = "Origin TLS overrides require exact hostnames of explicitly declared proxied records in this zone."
    }

    precondition {
      condition     = length(distinct(each.value.origin_tls_hostnames)) == length(each.value.origin_tls_hostnames)
      error_message = "Origin TLS override hostnames must be unique."
    }

    precondition {
      condition = alltrue([
        for ruleset in data.cloudflare_rulesets.origin_tls[each.key].rulesets :
        ruleset.phase != "http_config_settings" || (
          startswith(ruleset.name, "origin-tls-") &&
          ruleset.name == "origin-tls-${terraform_data.origin_tls_owner[each.key].id}"
        )
      ])
      error_message = "An existing configuration entrypoint is not owned by this stack. Stop for reviewed preservation/adoption; never replace its rules."
    }
  }
}
