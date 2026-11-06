mock_provider "azurerm" {}
mock_provider "cloudflare" {}
mock_provider "external" {}

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

run "pending_adoption_preserves_existing_dns" {
  command = plan

  variables {
    dns_zones_path = "tests/fixtures/pending-adoption"
  }

  assert {
    condition = (
      length(cloudflare_zone.managed) == 0 &&
      length(cloudflare_zone_setting.managed) == 0 &&
      length(cloudflare_ruleset.zone_custom_firewall) == 0 &&
      length(cloudflare_ruleset.origin_tls["example.invalid"].rules) == 1 &&
      cloudflare_dns_record.a["example.invalid|A|www|192.0.2.1"].zone_id == "00000000000000000000000000000001" &&
      output.dns_zones["example.invalid"].id == "00000000000000000000000000000001"
    )
    error_message = "A pending adoption must preserve the existing zone and DNS records without enabling zone-wide management."
  }
}

run "pending_adoption_requires_existing_zone_id" {
  command = plan

  variables {
    dns_zones_path = "tests/fixtures/pending-adoption-missing-id"
  }

  expect_failures = [terraform_data.pending_cloudflare_adoption["example.invalid"]]
}

run "activated_adoption_uses_discovered_zone" {
  command = plan

  variables {
    dns_zones_path               = "tests/fixtures/activated-adoption"
    cloudflare_account_id        = "00000000000000000000000000000000"
    cloudflare_adopted_zone_keys = ["example.invalid"]
  }

  override_data {
    target = data.cloudflare_zone.adopt["example.invalid"]
    values = { zone_id = "00000000000000000000000000000002" }
  }

  override_resource {
    target = cloudflare_zone.managed["example.invalid"]
    values = { id = "00000000000000000000000000000002" }
  }

  assert {
    condition = (
      length(terraform_data.pending_cloudflare_adoption) == 0 &&
      length(cloudflare_zone.managed) == 1 &&
      cloudflare_dns_record.a["example.invalid|A|www|192.0.2.1"].zone_id == "00000000000000000000000000000002" &&
      output.dns_zones["example.invalid"].id == "00000000000000000000000000000002"
    )
    error_message = "Activated adoption must use the discovered zone rather than the pending external identifier."
  }
}

run "preservation_rejects_missing_firewall" {
  command = plan

  variables {
    dns_zones_path               = "tests/fixtures/missing-firewall"
    cloudflare_account_id        = "00000000000000000000000000000000"
    cloudflare_adopted_zone_keys = ["example.invalid"]
  }

  override_data {
    target = data.cloudflare_zone.adopt["example.invalid"]
    values = { zone_id = "00000000000000000000000000000002" }
  }
  override_resource {
    target = cloudflare_zone.managed["example.invalid"]
    values = { id = "00000000000000000000000000000002" }
  }

  expect_failures = [cloudflare_ruleset.zone_custom_firewall["example.invalid"]]
}
