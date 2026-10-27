mock_provider "azurerm" {}
mock_provider "cloudflare" {}

mock_provider "external" {
  mock_data "external" {
    defaults = { result = { id = "00000000000000000000000000000001" } }
  }
}

override_resource {
  target = cloudflare_page_rule.legacy_apex_redirect["talkwithtiles.com"]
  values = { id = "00000000000000000000000000000001" }
}

override_data {
  target = data.terraform_remote_state.platform_workloads
  values = { outputs = {} }
}

override_resource {
  target = terraform_data.origin_tls_owner["xtremeidiots.net"]
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
    dns_zones_path        = "zones"
    maintenance_enabled   = true
    cloudflare_account_id = "00000000000000000000000000000000"
  }
  assert {
    condition = (
      length(cloudflare_workers_script.maintenance) == 2 &&
      length(cloudflare_workers_custom_domain.maintenance_canary) == 1 &&
      output.maintenance_runtime.version == 1 &&
      contains([for host in output.maintenance_runtime.hosts : host.hostname], "www.xtremeidiots.com") &&
      contains([for host in output.maintenance_runtime.hosts : host.hostname], "maps.xtremeidiots.com") &&
      !contains([for host in output.maintenance_runtime.hosts : host.hostname], "maps.xtremeidiots.net") &&
      !contains([for host in output.maintenance_runtime.hosts : host.hostname], "status.xtremeidiots.com")
    )
    error_message = "Production must expose independently controlled approved hosts and never the status destination."
  }
}
