mock_provider "azurerm" {}

mock_provider "cloudflare" {}

mock_provider "external" {
  mock_data "external" {
    defaults = { result = { id = "00000000000000000000000000000001" } }
  }
}

override_resource {
  target = cloudflare_page_rule.legacy_apex_redirect["example.test"]
  values = { id = "00000000000000000000000000000001" }
}

override_data {
  target = data.terraform_remote_state.platform_workloads
  values = {
    outputs = {}
  }
}

override_resource {
  target = terraform_data.origin_tls_owner["edge.example.test"]
  values = {
    id = "00000000-0000-0000-0000-000000000001"
  }
}

variables {
  subscription_id       = "00000000-0000-0000-0000-000000000000"
  dns_zones_path        = "tests/fixtures/connectivity-hosts"
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

run "retired_hostname_keeps_empty_owned_configuration_phase" {
  command = plan

  variables {
    dns_zones_path = "tests/fixtures/retired"
  }

  assert {
    condition = (
      length(cloudflare_ruleset.origin_tls) == 1 &&
      length(cloudflare_ruleset.origin_tls["edge.example.test"].rules) == 0 &&
      length(cloudflare_zone_setting.managed) == 0
    )
    error_message = "Retiring maps must clear its old rule without destroying the protected zone entrypoint or managing external zone settings."
  }
}

run "synthetic_origin_tls_is_strict_for_both_proxied_hosts" {
  command = plan

  assert {
    condition = (
      toset([for rule in cloudflare_ruleset.origin_tls["example.test"].rules : rule.expression]) ==
      toset(["http.host eq \"example.test\"", "http.host eq \"www.example.test\""]) &&
      alltrue([
        for rule in cloudflare_ruleset.origin_tls["example.test"].rules :
        rule.enabled && rule.action == "set_config" && rule.action_parameters.ssl == "strict"
      ]) &&
      toset([for rule in cloudflare_ruleset.origin_tls["edge.example.test"].rules : rule.expression]) ==
      toset(["http.host eq \"redirect.edge.example.test\""]) &&
      alltrue([
        for rule in cloudflare_ruleset.origin_tls["edge.example.test"].rules :
        rule.enabled && rule.action == "set_config" && rule.action_parameters.ssl == "strict"
      ]) &&
      alltrue([for setting in local.managed_cloudflare_zone_settings : !contains(["example.test", "edge.example.test"], setting.zone_key)])
    )
    error_message = "Synthetic zones must enforce strict origin TLS only for their selected proxied hosts without changing external zone settings."
  }
}

run "legacy_redirect_is_imported_disabled_without_changing_its_target" {
  command = plan

  assert {
    condition = (
      length(cloudflare_page_rule.legacy_apex_redirect) == 1 &&
      cloudflare_page_rule.legacy_apex_redirect["example.test"].status == "disabled" &&
      cloudflare_page_rule.legacy_apex_redirect["example.test"].target == "https://example.test/*" &&
      cloudflare_page_rule.legacy_apex_redirect["example.test"].actions.forwarding_url.url == "https://www.example.test/" &&
      cloudflare_page_rule.legacy_apex_redirect["example.test"].actions.forwarding_url.status_code == 301 &&
      cloudflare_page_rule.legacy_apex_redirect["example.test"].priority == 1
    )
    error_message = "Only the explicitly opted-in legacy redirect may be adopted, retaining its exact configuration except disabled status."
  }
}

run "unproxied_hostname_is_rejected" {
  command = plan

  variables {
    dns_zones_path = "tests/fixtures/unproxied"
  }

  expect_failures = [cloudflare_ruleset.origin_tls["edge.example.test"]]
}

run "duplicate_hostname_is_rejected" {
  command = plan

  variables {
    dns_zones_path = "tests/fixtures/duplicate"
  }

  expect_failures = [cloudflare_ruleset.origin_tls["edge.example.test"]]
}

run "new_managed_zone_override_is_rejected_explicitly" {
  command = plan

  variables {
    dns_zones_path        = "tests/fixtures/managed"
    cloudflare_account_id = "00000000000000000000000000000000"
  }

  expect_failures = [terraform_data.origin_tls_owner["new.invalid"]]
}

run "adopted_zone_preserves_existing_origin_owner_and_disabled_redirect" {
  command = plan

  variables {
    dns_zones_path = "tests/fixtures/preserved-origin"
  }

  override_resource {
    target          = terraform_data.origin_tls_owner["example.invalid"]
    values          = { id = "00000000-0000-0000-0000-000000000002" }
    override_during = plan
  }
  override_data {
    target = data.cloudflare_zone.adopt["example.invalid"]
    values = { zone_id = "00000000000000000000000000000002" }
  }
  override_resource {
    target = cloudflare_zone.managed["example.invalid"]
    values = { id = "00000000000000000000000000000002" }
  }
  override_resource {
    target = cloudflare_zone_dnssec.managed["example.invalid"]
  }
  override_resource {
    target = cloudflare_zone_setting.managed["example.invalid/ssl"]
  }
  override_resource {
    target = cloudflare_ruleset.origin_tls["example.invalid"]
  }
  override_resource {
    target = cloudflare_page_rule.legacy_apex_redirect["example.invalid"]
  }
  override_data {
    target = data.external.cloudflare_zone_settings_snapshot["example.invalid"]
    values = { result = { matches = "true", differences = "[]" } }
  }
  override_data {
    target = data.cloudflare_rulesets.origin_tls["example.invalid"]
    values = {
      rulesets = {
        id           = "00000000000000000000000000000003"
        name         = "origin-tls-00000000-0000-0000-0000-000000000002"
        phase        = "http_config_settings"
        kind         = "zone"
        description  = ""
        last_updated = "2020-01-01T00:00:00Z"
        version      = "1"
      }
    }
  }

  assert {
    condition = (
      cloudflare_ruleset.origin_tls["example.invalid"].name == "origin-tls-00000000-0000-0000-0000-000000000002" &&
      length(cloudflare_ruleset.origin_tls["example.invalid"].rules) == 2 &&
      cloudflare_zone_setting.managed["example.invalid/ssl"].value == "full" &&
      cloudflare_page_rule.legacy_apex_redirect["example.invalid"].status == "disabled"
    )
    error_message = "Adoption must retain the existing owner identity and disabled redirect without hardening the zone-wide SSL setting."
  }
}
