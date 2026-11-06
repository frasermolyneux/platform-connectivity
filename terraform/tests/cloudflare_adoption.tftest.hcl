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

run "preserved_controls_stay_inactive_before_adoption" {
  command = plan

  variables {
    dns_zones_path = "tests/fixtures/preserved-controls"
  }

  assert {
    condition = (
      length(cloudflare_ruleset.preserved) == 0 &&
      length(cloudflare_page_rule.preserved) == 0 &&
      length(data.external.preserved_rulesets) == 0 &&
      length(data.external.preserved_page_rules) == 0
    )
    error_message = "Preserved zone controls must not be discovered or owned before adoption is enabled."
  }
}

run "activated_adoption_preserves_existing_controls" {
  command = plan

  variables {
    dns_zones_path               = "tests/fixtures/preserved-controls"
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
  override_data {
    target = data.external.preserved_rulesets["example.invalid"]
    values = {
      result = {
        http_ratelimit_id = "00000000000000000000000000000003"
        http_ratelimit_rules = jsonencode([{
          ref        = "00000000000000000000000000000004"
          action     = "managed_challenge"
          enabled    = true
          expression = "true"
          ratelimit = {
            characteristics     = ["ip.src", "cf.colo.id"]
            period              = 10
            requests_per_period = 50
            mitigation_timeout  = 0
          }
        }])
      }
    }
  }
  override_data {
    target = data.external.preserved_page_rules["example.invalid"]
    values = { result = { test = "00000000000000000000000000000005" } }
  }
  override_resource {
    target = cloudflare_ruleset.preserved["example.invalid|http_ratelimit"]
  }
  override_resource {
    target = cloudflare_page_rule.preserved["example.invalid|test"]
  }

  assert {
    condition = (
      cloudflare_ruleset.preserved["example.invalid|http_ratelimit"].phase == "http_ratelimit" &&
      cloudflare_ruleset.preserved["example.invalid|http_ratelimit"].rules[0].ratelimit.requests_per_period == 50 &&
      cloudflare_page_rule.preserved["example.invalid|test"].actions.ssl == "full" &&
      cloudflare_page_rule.preserved["example.invalid|test"].status == "active"
    )
    error_message = "Activated adoption must preserve the discovered rate-limit and Page Rule configuration."
  }
}
