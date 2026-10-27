mock_provider "azurerm" {}

mock_provider "cloudflare" {}

override_data {
  target = data.terraform_remote_state.platform_workloads
  values = {
    outputs = {}
  }
}

override_resource {
  target = terraform_data.origin_tls_owner["xtremeidiots.net"]
  values = {
    id = "00000000-0000-0000-0000-000000000001"
  }
}

variables {
  subscription_id      = "00000000-0000-0000-0000-000000000000"
  dns_zones_path       = "zones"
  cloudflare_api_token = "unused_placeholder_token_dev_environment"
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
      length(cloudflare_ruleset.origin_tls["xtremeidiots.net"].rules) == 0 &&
      length(cloudflare_zone_setting.managed) == 0
    )
    error_message = "Retiring maps must clear its old rule without destroying the protected zone entrypoint or managing external zone settings."
  }
}

run "talk_origin_tls_is_strict_for_both_proxied_hosts" {
  command = plan

  assert {
    condition = (
      toset([for rule in cloudflare_ruleset.origin_tls["talkwithtiles.com"].rules : rule.expression]) ==
      toset(["http.host eq \"talkwithtiles.com\"", "http.host eq \"www.talkwithtiles.com\""]) &&
      alltrue([
        for rule in cloudflare_ruleset.origin_tls["talkwithtiles.com"].rules :
        rule.enabled && rule.action == "set_config" && rule.action_parameters.ssl == "strict"
      ]) &&
      length(cloudflare_ruleset.origin_tls["xtremeidiots.net"].rules) == 0 &&
      length(cloudflare_zone_setting.managed) == 0
    )
    error_message = "Talk must enforce strict origin TLS only for its two proxied hosts without changing retired maps or external zone settings."
  }
}

run "unproxied_hostname_is_rejected" {
  command = plan

  variables {
    dns_zones_path = "tests/fixtures/unproxied"
  }

  expect_failures = [cloudflare_ruleset.origin_tls["xtremeidiots.net"]]
}

run "duplicate_hostname_is_rejected" {
  command = plan

  variables {
    dns_zones_path = "tests/fixtures/duplicate"
  }

  expect_failures = [cloudflare_ruleset.origin_tls["xtremeidiots.net"]]
}

run "new_managed_zone_override_is_rejected_explicitly" {
  command = plan

  variables {
    dns_zones_path               = "tests/fixtures/managed"
    cloudflare_account_id        = "00000000000000000000000000000000"
    cloudflare_adopted_zone_keys = ["new.invalid"]
  }

  expect_failures = [terraform_data.origin_tls_owner["new.invalid"]]
}
