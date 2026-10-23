locals {
  cloudflare_origin_tls_zones = {
    for key, zone in local.active_cloudflare_zones : key => zone
    if length(try(zone.origin_tls_hostnames, [])) > 0
  }
}

data "cloudflare_rulesets" "origin_tls" {
  for_each = local.cloudflare_origin_tls_zones

  zone_id = local.cloudflare_zone_ids[each.value.name]
}

resource "cloudflare_ruleset" "origin_tls" {
  for_each = local.cloudflare_origin_tls_zones

  zone_id     = local.cloudflare_zone_ids[each.value.name]
  name        = "Terraform-managed hostname origin TLS"
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
        for ruleset in data.cloudflare_rulesets.origin_tls[each.key].result :
        ruleset.phase != "http_config_settings" || ruleset.name == "Terraform-managed hostname origin TLS"
      ])
      error_message = "An existing configuration entrypoint is not owned by this stack. Stop for reviewed preservation/adoption; never replace its rules."
    }
  }
}
