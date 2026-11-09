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
  values = { outputs = {} }
}

override_resource {
  target = terraform_data.origin_tls_owner["edge.example.test"]
  values = { id = "00000000-0000-0000-0000-000000000001" }
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

run "development_has_no_workers_or_runtime_contract" {
  command = plan
  assert {
    condition     = length(cloudflare_workers_script.maintenance) == 0 && length(cloudflare_workers_custom_domain.maintenance_canary) == 0 && output.maintenance_runtime == null
    error_message = "Maintenance must not be provisioned in the default development environment."
  }
}

run "production_deploys_worker_modes_and_exact_host_registry" {
  command = plan
  variables {
    environment           = "prd"
    dns_zones_path        = "tests/fixtures/connectivity-hosts"
    maintenance_enabled   = true
    cloudflare_account_id = "00000000000000000000000000000000"
    maintenance_hosts_override = jsonencode([
      { hostname = "maintenance-check.example.test", zone = "example.test", site = "mx", canary = true },
      { hostname = "example.test", zone = "example.test", site = "mx" },
      { hostname = "www.example.test", zone = "example.test", site = "mx" },
      { hostname = "maps.example.test", zone = "example.test", site = "mx" },
      { hostname = "redirect.edge.example.test", zone = "edge.example.test", site = "xi" }
    ])
  }
  assert {
    condition = (
      length(cloudflare_workers_script.maintenance) == 2 &&
      length(cloudflare_workers_custom_domain.maintenance_canary) == 1 &&
      output.maintenance_runtime.version == 1 &&
      cloudflare_workers_custom_domain.maintenance_canary[0].hostname == "maintenance-check.example.test" &&
      contains([for host in output.maintenance_runtime.hosts : host.hostname], "www.example.test") &&
      contains([for host in output.maintenance_runtime.hosts : host.hostname], "maps.example.test") &&
      contains([for host in output.maintenance_runtime.hosts : host.hostname], "redirect.edge.example.test") &&
      !contains([for host in output.maintenance_runtime.hosts : host.hostname], "status.example.test")
    )
    error_message = "Production maintenance tests must use synthetic approved hosts and a synthetic canary domain."
  }
}
