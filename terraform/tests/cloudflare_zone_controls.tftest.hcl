mock_provider "azurerm" {}
mock_provider "cloudflare" {}

override_data {
  target = data.terraform_remote_state.platform_workloads
  values = { outputs = {} }
}

variables {
  subscription_id       = "00000000-0000-0000-0000-000000000000"
  cloudflare_api_token  = "unused_placeholder_token_dev_environment"
  cloudflare_account_id = "00000000000000000000000000000000"
  platform_workloads_state = {
    resource_group_name  = "unused"
    storage_account_name = "unused"
    container_name       = "unused"
    key                  = "unused"
    subscription_id      = "00000000-0000-0000-0000-000000000000"
    tenant_id            = "00000000-0000-0000-0000-000000000000"
  }
}

run "zone_controls_are_configuration_driven" {
  command = plan

  variables {
    dns_zones_path = "tests/fixtures/configured-zone-controls"
  }

  override_resource {
    target = cloudflare_zone.managed["example.invalid"]
    values = { id = "00000000000000000000000000000002" }
  }
  override_resource {
    target = cloudflare_zone_dnssec.managed["example.invalid"]
    values = { id = "00000000000000000000000000000002" }
  }
  override_resource {
    target = cloudflare_zone_setting.managed["example.invalid/ssl"]
    values = { id = "00000000000000000000000000000002/ssl" }
  }
  assert {
    condition = (
      cloudflare_ruleset.zone_configured["example.invalid/http_ratelimit"].phase == "http_ratelimit" &&
      cloudflare_ruleset.zone_configured["example.invalid/http_ratelimit"].rules[0].ratelimit.requests_per_period == 50 &&
      cloudflare_ruleset.zone_configured["example.invalid/http_ratelimit"].rules[0].ref == "synthetic-rate-limit" &&
      cloudflare_ruleset.zone_custom_firewall["example.invalid"].rules[0].ref == "synthetic-firewall-rule" &&
      cloudflare_page_rule.managed["example.invalid/stats"].target == "https://stats.example.invalid/*" &&
      cloudflare_page_rule.managed["example.invalid/stats"].actions.ssl == "full" &&
      local.cloudflare_zone_rulesets["example.invalid/http_ratelimit"].phase == "http_ratelimit"
    )
    error_message = "Rulesets and Page Rules must be configured directly with stable rule references."
  }
}

run "ruleset_rules_require_explicit_references" {
  command = plan

  variables {
    dns_zones_path        = "tests/fixtures/missing-rule-refs"
    cloudflare_account_id = "00000000000000000000000000000000"
  }

  expect_failures = [
    cloudflare_ruleset.zone_configured["example.invalid/http_ratelimit"],
    cloudflare_ruleset.zone_custom_firewall["example.invalid"]
  ]
}
