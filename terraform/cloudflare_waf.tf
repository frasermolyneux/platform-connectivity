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
      condition = alltrue([
        for rule in try(each.value.waf_custom_ruleset.rules, []) : try(trimspace(rule.ref), "") != ""
      ])
      error_message = "Each configured custom-firewall rule in ${each.value.name} requires an explicit stable ref."
    }
  }

  rules = try(each.value.waf_custom_ruleset.rules, [
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
