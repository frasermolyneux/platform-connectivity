mock_provider "azurerm" {}

provider "cloudflare" {
  api_token = "unused_placeholder_token_dev_environment"
}

override_data {
  target = data.terraform_remote_state.platform_workloads
  values = { outputs = {} }
}

variables {
  subscription_id       = "00000000-0000-0000-0000-000000000000"
  cloudflare_api_token  = "unused_placeholder_token_dev_environment"
  cloudflare_account_id = "00000000000000000000000000000000"
  dns_zones_path        = "tests/fixtures/adoption"
  platform_workloads_state = {
    resource_group_name  = "unused"
    storage_account_name = "unused"
    container_name       = "unused"
    key                  = "unused"
    subscription_id      = "00000000-0000-0000-0000-000000000000"
    tenant_id            = "00000000-0000-0000-0000-000000000000"
  }
}

run "imports_existing_zone_and_records" {
  command = plan

  assert {
    condition = (
      local.cloudflare_record_adoptions["example.invalid|MX|mail"].name == "example.invalid" &&
      local.cloudflare_record_adoptions["example.invalid|SRV|service"].name == "_sip._tcp.example.invalid" &&
      length(cloudflare_ruleset.zone_custom_firewall) == 0
    )
    error_message = "Adoption must resolve record names and avoid claiming the existing custom-firewall phase."
  }
}
