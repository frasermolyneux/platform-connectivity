mock_provider "azurerm" {}
mock_provider "cloudflare" {}

override_data {
  target = data.terraform_remote_state.platform_workloads
  values = { outputs = {} }
}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  platform_workloads_state = {
    resource_group_name  = "unused"
    storage_account_name = "unused"
    container_name       = "unused"
    key                  = "unused"
    subscription_id      = "00000000-0000-0000-0000-000000000000"
    tenant_id            = "00000000-0000-0000-0000-000000000000"
  }
}

run "empty_production_list_provisions_no_private_zones" {
  command = plan

  variables {
    private_link_zones_file = "private_link_zones/prd.json"
  }

  assert {
    condition     = length(azurerm_private_dns_zone.zones) == 0
    error_message = "An empty private zone list must provision no private DNS zones."
  }
}

run "configured_private_zone_can_be_reintroduced" {
  command = plan

  variables {
    private_link_zones_file = "tests/fixtures/private-link-zones.json"
  }

  assert {
    condition = (
      length(azurerm_private_dns_zone.zones) == 1 &&
      azurerm_private_dns_zone.zones["privatelink.example.invalid"].name == "privatelink.example.invalid" &&
      azurerm_private_dns_zone.zones["privatelink.example.invalid"].resource_group_name == azurerm_resource_group.dns.name
    )
    error_message = "The retained loader and resource loop must provision configured private DNS zones."
  }
}
