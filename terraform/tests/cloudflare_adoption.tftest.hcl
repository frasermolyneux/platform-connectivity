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

override_resource {
  target = cloudflare_zone_setting.managed["example.invalid/always_use_https"]
}
override_resource {
  target = cloudflare_zone_setting.managed["example.invalid/automatic_https_rewrites"]
}
override_resource {
  target = cloudflare_zone_setting.managed["example.invalid/brotli"]
}
override_resource {
  target = cloudflare_zone_setting.managed["example.invalid/browser_check"]
}
override_resource {
  target = cloudflare_zone_setting.managed["example.invalid/http2"]
}
override_resource {
  target = cloudflare_zone_setting.managed["example.invalid/http3"]
}
override_resource {
  target = cloudflare_zone_setting.managed["example.invalid/ipv6"]
}
override_resource {
  target = cloudflare_zone_setting.managed["example.invalid/min_tls_version"]
}
override_resource {
  target = cloudflare_zone_setting.managed["example.invalid/security_level"]
}
override_resource {
  target = cloudflare_zone_setting.managed["example.invalid/ssl"]
}
override_resource {
  target = cloudflare_zone_setting.managed["example.invalid/tls_1_3"]
}
override_resource {
  target = cloudflare_zone_dnssec.managed["example.invalid"]
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

run "external_ownership_preserves_existing_dns" {
  command = plan

  variables {
    dns_zones_path = "tests/fixtures/external"
  }

  assert {
    condition = (
      length(cloudflare_zone.managed) == 0 &&
      length(local.cloudflare_zones_to_adopt) == 0 &&
      length(cloudflare_zone_setting.managed) == 0 &&
      length(cloudflare_ruleset.zone_custom_firewall) == 0 &&
      length(cloudflare_ruleset.origin_tls["example.invalid"].rules) == 1 &&
      cloudflare_dns_record.a["example.invalid|A|www|192.0.2.1"].zone_id == "00000000000000000000000000000001" &&
      output.dns_zones["example.invalid"].id == "00000000000000000000000000000001"
    )
    error_message = "External ownership must preserve existing DNS and TLS without enabling zone-wide management, even with adopt_existing set."
  }
}

run "management_declaration_adopts_existing_zone_without_allowlist" {
  command = plan

  variables {
    dns_zones_path        = "tests/fixtures/activated-adoption"
    cloudflare_account_id = "00000000000000000000000000000000"
  }

  override_data {
    target = data.cloudflare_zone.adopt["example.invalid"]
    values = { zone_id = "00000000000000000000000000000002" }
  }
  override_data {
    target = data.external.cloudflare_zone_settings_snapshot["example.invalid"]
    values = { result = { matches = "true", differences = "[]" } }
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
      length(local.cloudflare_zones_to_adopt) == 1 &&
      length(cloudflare_zone.managed) == 1 &&
      cloudflare_dns_record.a["example.invalid|A|www"].zone_id == "00000000000000000000000000000002" &&
      length(local.managed_cloudflare_zone_settings) == 1 &&
      output.dns_zones["example.invalid"].id == "00000000000000000000000000000002"
    )
    error_message = "An existing Terraform-managed zone must use its discovered zone rather than its external identifier."
  }
}

run "adoption_rejects_settings_drift" {
  command = plan

  variables {
    dns_zones_path        = "tests/fixtures/activated-adoption"
    cloudflare_account_id = "00000000000000000000000000000000"
  }

  override_data {
    target = data.cloudflare_zone.adopt["example.invalid"]
    values = { zone_id = "00000000000000000000000000000002" }
  }
  override_data {
    target = data.external.cloudflare_zone_settings_snapshot["example.invalid"]
    values = { result = { matches = "false", differences = "[\"ssl\"]" } }
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

  expect_failures = [cloudflare_zone_setting.managed["example.invalid/ssl"]]
}

run "managed_new_zone_needs_no_adoption" {
  command = plan

  variables {
    dns_zones_path        = "tests/fixtures/new-zone"
    cloudflare_account_id = "00000000000000000000000000000000"
  }

  assert {
    condition = (
      length(cloudflare_zone.managed) == 1 &&
      length(cloudflare_zone_dnssec.managed) == 1 &&
      length(cloudflare_zone_setting.managed) == 11 &&
      length(cloudflare_ruleset.zone_custom_firewall) == 1 &&
      length(local.cloudflare_zones_to_adopt) == 0
    )
    error_message = "A new zone declared Terraform-managed must enable its controls without attempting discovery or import."
  }
}

run "preservation_rejects_missing_firewall" {
  command = plan

  variables {
    dns_zones_path        = "tests/fixtures/missing-firewall"
    cloudflare_account_id = "00000000000000000000000000000000"
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
    target = cloudflare_zone_setting.managed["example.invalid/ssl"]
    values = { id = "00000000000000000000000000000002/ssl" }
  }

  expect_failures = [cloudflare_ruleset.zone_custom_firewall["example.invalid"]]
}
