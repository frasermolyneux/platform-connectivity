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
  command   = apply
  state_key = "zone_controls"

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
  override_data {
    target = data.cloudflare_bot_management.existing["example.invalid"]
    values = {
      ai_bots_migration_opt_out = true
      is_robots_txt_managed     = true
    }
  }
  assert {
    condition = (
      length(cloudflare_bot_management.managed) == 1 &&
      cloudflare_bot_management.managed["example.invalid"].zone_id == cloudflare_zone.managed["example.invalid"].id &&
      cloudflare_bot_management.managed["example.invalid"].fight_mode == false &&
      cloudflare_bot_management.managed["example.invalid"].sbfm_definitely_automated == "managed_challenge" &&
      cloudflare_bot_management.managed["example.invalid"].sbfm_verified_bots == "allow" &&
      cloudflare_bot_management.managed["example.invalid"].ai_bots_migration_opt_out == true &&
      cloudflare_bot_management.managed["example.invalid"].is_robots_txt_managed == true
    )
    error_message = "Super Bot Fight Mode must use the requested Pro settings and preserve existing AI and robots.txt preferences."
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

run "sbfm_settings_are_configurable_without_claiming_other_zones" {
  command   = apply
  state_key = "sbfm_configured"

  variables {
    dns_zones_path = "tests/fixtures/multi-zone"
  }

  override_resource {
    target = cloudflare_zone.managed["api.example.test"]
    values = { id = "00000000000000000000000000000003" }
  }
  override_data {
    target = data.cloudflare_bot_management.existing["api.example.test"]
    values = {
      ai_bots_migration_opt_out = false
      is_robots_txt_managed     = false
    }
  }
  assert {
    condition = (
      toset(keys(cloudflare_bot_management.managed)) == toset(["api.example.test"]) &&
      toset(keys(data.cloudflare_bot_management.existing)) == toset(["api.example.test"]) &&
      cloudflare_bot_management.managed["api.example.test"].fight_mode == false &&
      cloudflare_bot_management.managed["api.example.test"].sbfm_definitely_automated == "managed_challenge" &&
      cloudflare_bot_management.managed["api.example.test"].sbfm_verified_bots == "allow" &&
      cloudflare_bot_management.managed["api.example.test"].ai_bots_migration_opt_out == false &&
      cloudflare_bot_management.managed["api.example.test"].is_robots_txt_managed == false
    )
    error_message = "Pro Super Bot Fight settings must be explicit, preserve existing preferences, and exclude externally managed zones."
  }
}

run "dev_has_no_bot_management" {
  command = plan

  variables {
    dns_zones_path = ""
  }

  assert {
    condition = (
      length(cloudflare_bot_management.managed) == 0 &&
      length(data.cloudflare_bot_management.existing) == 0
    )
    error_message = "Dev must not read or manage Cloudflare bot settings."
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

run "managed_waf_uses_plan_and_explicit_http_hosts" {
  command = plan

  variables {
    dns_zones_path = "tests/fixtures/managed-waf"
  }

  assert {
    condition = (
      cloudflare_ruleset.zone_configured["free.example.test/http_request_firewall_managed"].rules[0].action_parameters.id == "77454fe2d30c4220b5701f6fdfb893ba" &&
      cloudflare_ruleset.zone_configured["free.example.test/http_request_firewall_managed"].rules[0].expression == "http.host in {\"free.example.test\" \"www.free.example.test\"}" &&
      cloudflare_ruleset.zone_configured["pro.example.test/http_request_firewall_managed"].rules[0].action_parameters.id == "efb7b8c949ac4650a09736fc376e9aee" &&
      !contains(keys(local.cloudflare_zone_rulesets), "mail.example.test/http_request_firewall_managed") &&
      cloudflare_ruleset.zone_configured["configured.example.test/http_request_firewall_managed"].rules[0].ref == "existing-rule"
    )
    error_message = "Managed WAF must use the plan-appropriate ruleset for declared HTTP hosts, preserve existing rulesets and exclude non-HTTP zones."
  }
}

run "create_retired_page_rule_in_test_state" {
  command   = apply
  state_key = "retired_tcadmin"

  module {
    source = "./tests/fixtures/tcadmin-before"
  }

  assert {
    condition     = cloudflare_page_rule.managed["xtremeidiots.com/tcadmin"].target == "*tcadmin.xtremeidiots.com/*"
    error_message = "The synthetic retired Page Rule must exist before testing its removal."
  }
}

run "retire_only_tcadmin_page_rule" {
  command   = plan
  state_key = "retired_tcadmin"

  variables {
    dns_zones_path = "tests/fixtures/tcadmin-after"
  }

  assert {
    condition     = length(cloudflare_page_rule.retired_tcadmin) == 0 && length(cloudflare_page_rule.managed) == 0
    error_message = "The retired Page Rule should be removed without disabling protection on other Page Rules."
  }
}
