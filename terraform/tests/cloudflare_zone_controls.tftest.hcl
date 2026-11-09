mock_provider "azurerm" {}
mock_provider "cloudflare" {}
mock_provider "external" {
  mock_data "external" {
    defaults = { result = { matches = "true" } }
  }
}

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

  override_data {
    target = data.cloudflare_zone.adopt["example.invalid"]
    values = { zone_id = "00000000000000000000000000000002" }
  }
  override_data {
    target = data.external.cloudflare_page_rule["example.invalid/stats"]
    values = { result = { id = "" } }
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
      cloudflare_page_rule.managed["example.invalid/stats"].target == "https://stats.example.invalid/*" &&
      cloudflare_page_rule.managed["example.invalid/stats"].actions.ssl == "full" &&
      length(local.cf_zone_ruleset_imports) == 0 &&
      local.cloudflare_zone_rulesets["example.invalid/http_ratelimit"].phase == "http_ratelimit"
    )
    error_message = "Missing rulesets and Page Rules on an adopted zone must be created from configuration without imports."
  }
}
