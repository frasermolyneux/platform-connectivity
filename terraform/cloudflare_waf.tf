resource "cloudflare_ruleset" "zone_custom_firewall" {
  for_each = {
    for key, zone in local.managed_cloudflare_zones : key => zone
    if try(zone.waf_custom_rules_enabled, true)
  }

  zone_id     = cloudflare_zone.managed[each.key].id
  name        = "Terraform-managed custom firewall rules"
  description = "Shared Free-plan-compatible protection for common automated probes"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  lifecycle {
    precondition {
      condition     = length(try(local.cf_waf_ruleset_ids[each.key], [])) <= 1
      error_message = "Zone ${each.value.name} has more than one http_request_firewall_custom entrypoint ruleset; resolve to a single ruleset before adoption so it can be imported rather than recreated."
    }
  }

  rules = [
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
  ]
}
