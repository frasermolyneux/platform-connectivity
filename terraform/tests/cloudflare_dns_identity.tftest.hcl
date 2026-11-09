mock_provider "azurerm" {}
mock_provider "cloudflare" {}
override_data {
  target = data.terraform_remote_state.platform_workloads
  values = { outputs = {} }
}

variables {
  subscription_id      = "00000000-0000-0000-0000-000000000000"
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

run "explicit_keys_are_content_independent_and_srv_fields_are_preserved" {
  command = plan

  variables {
    dns_zones_path = "tests/fixtures/stable-identities"
  }

  assert {
    condition = (
      toset(keys(local.cf_a_records)) == toset(["example.test|A|web-origin"]) &&
      toset(keys(local.cf_srv_records)) == toset([
        "example.test|SRV|service-primary",
        "example.test|SRV|service-secondary"
      ]) &&
      local.cf_srv_records["example.test|SRV|service-primary"].data.priority == 10 &&
      local.cf_srv_records["example.test|SRV|service-secondary"].data.priority == 20 &&
      local.cf_srv_records["example.test|SRV|service-primary"].data.target == "server.example.test" &&
      local.cf_srv_records["example.test|SRV|service-secondary"].data.weight == 5
    )
    error_message = "Explicit record keys must determine addresses, and Cloudflare SRV records must preserve priority and weight."
  }
}

run "content_change_keeps_explicit_resource_address" {
  command = plan

  variables {
    dns_zones_path = "tests/fixtures/stable-identities-changed"
  }

  assert {
    condition = (
      keys(local.cf_a_records)[0] == "example.test|A|web-origin" &&
      local.cf_a_records["example.test|A|web-origin"].content == "198.51.100.10"
    )
    error_message = "Changing record content must not change its explicit Terraform address."
  }
}

run "multiple_managed_and_external_zones_keep_distinct_controls" {
  command = plan

  variables {
    dns_zones_path        = "tests/fixtures/multi-zone"
    cloudflare_account_id = "00000000000000000000000000000000"
  }

  assert {
    condition = (
      length(cloudflare_zone.managed) == 2 &&
      length(cloudflare_dns_record.a) == 2 &&
      length(cloudflare_dns_record.cname) == 1 &&
      length(cloudflare_ruleset.zone_configured) == 1 &&
      length(cloudflare_page_rule.managed) == 1 &&
      length(cloudflare_ruleset.zone_custom_firewall) == 1 &&
      !contains(keys(local.managed_cloudflare_zones), "external.example.invalid")
    )
    error_message = "Multiple synthetic zones with different controls must preserve the external ownership boundary."
  }
}

run "unsupported_record_types_fail_closed" {
  command = plan

  variables {
    dns_zones_path = "tests/fixtures/unsupported-record"
  }

  expect_failures = [azurerm_resource_group.dns]
}

run "managed_records_require_explicit_keys" {
  command = plan

  variables {
    dns_zones_path        = "tests/fixtures/managed-missing-key"
    cloudflare_account_id = "00000000000000000000000000000000"
  }

  expect_failures = [
    azurerm_resource_group.dns,
    cloudflare_zone.managed["new.invalid"]
  ]
}

run "preserved_settings_do_not_expand_profile_defaults" {
  command = plan

  variables {
    dns_zones_path        = "tests/fixtures/preserved-settings"
    cloudflare_account_id = "00000000000000000000000000000000"
  }

  assert {
    condition = (
      length(local.managed_cloudflare_zone_settings) == 1 &&
      contains(keys(local.managed_cloudflare_zone_settings), "example.invalid/ssl") &&
      local.managed_cloudflare_zone_settings["example.invalid/ssl"].value == "strict"
    )
    error_message = "settings_preserve_existing must limit management to explicitly configured settings instead of inheriting profile defaults."
  }
}
