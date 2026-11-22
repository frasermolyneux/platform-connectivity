mock_provider "azurerm" {}
mock_provider "cloudflare" {}

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

run "catalog_adds_only_enrolled_canonical_hosts" {
  command = plan
  assert {
    condition = (
      jsonencode([for host in local.maintenance_hosts : host if !contains(local.maintenance_enrolled_catalog_hosts, host.hostname)]) ==
      jsonencode(jsondecode(file("tests/fixtures/maintenance-hosts-baseline.json")))
    )
    error_message = "The existing registry, including canary, legacy aliases and unrelated hosts, must remain unchanged."
  }
  assert {
    condition = (
      length(local.maintenance_hosts) == length(distinct([for host in local.maintenance_hosts : host.hostname])) &&
      length(setintersection(toset(keys(local.maintenance_catalog_hosts)), toset([for host in local.maintenance_extra_hosts : host.hostname]))) == 0 &&
      toset([for host in local.maintenance_hosts : host.hostname if contains(local.maintenance_enrolled_catalog_hosts, host.hostname)]) == local.maintenance_enrolled_catalog_hosts &&
      alltrue([for host in local.maintenance_hosts : host.site == "mx" && host.zone == host.hostname if contains(local.maintenance_enrolled_catalog_hosts, host.hostname)]) &&
      !contains(keys(local.maintenance_catalog_hosts), "www.talkwithtiles.com") &&
      !contains(keys(local.maintenance_catalog_hosts), "www.tripsidekick.app") &&
      !contains(keys(local.maintenance_catalog_hosts), "www.tripsidekick.net") &&
      !contains(keys(local.maintenance_catalog_hosts), "idp.molyneux.io") &&
      !contains(keys(local.maintenance_catalog_hosts), "mxstatus.io")
    )
    error_message = "Only the three canonical catalog hosts may be enrolled; aliases and unrelated targets remain excluded."
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

run "externally_owned_proxied_record_is_accepted" {
  command = plan
  variables {
    environment           = "prd"
    dns_zones_path        = "tests/fixtures/connectivity-hosts"
    maintenance_enabled   = true
    cloudflare_account_id = "00000000000000000000000000000000"
    maintenance_hosts_override = jsonencode([
      { hostname = "maintenance-check.example.test", zone = "example.test", site = "mx", canary = true },
      { hostname = "external.example.test", zone = "example.test", site = "mx" }
    ])
    maintenance_external_dns_override = jsonencode({
      "external.example.test" = [{ name = "external.example.test", type = "A", proxied = true }]
    })
  }
  assert {
    condition     = contains([for host in output.maintenance_runtime.hosts : host.hostname], "external.example.test")
    error_message = "An exact externally owned proxied web record must be admitted without managing DNS."
  }
}

run "externally_owned_unproxied_record_is_rejected" {
  command = plan
  variables {
    environment           = "prd"
    dns_zones_path        = "tests/fixtures/connectivity-hosts"
    maintenance_enabled   = true
    cloudflare_account_id = "00000000000000000000000000000000"
    maintenance_hosts_override = jsonencode([
      { hostname = "maintenance-check.example.test", zone = "example.test", site = "mx", canary = true },
      { hostname = "external.example.test", zone = "example.test", site = "mx" }
    ])
    maintenance_external_dns_override = jsonencode({
      "external.example.test" = [
        { name = "external.example.test", type = "A", proxied = false },
        { name = "another.example.test", type = "A", proxied = true },
        { name = "external.example.test", type = "MX", proxied = true }
      ]
    })
  }
  expect_failures = [
    cloudflare_workers_script.maintenance["page"],
    cloudflare_workers_script.maintenance["redirect"]
  ]
}

run "declared_dns_only_record_is_not_validated_against_stale_external_dns" {
  command = plan
  variables {
    environment           = "prd"
    dns_zones_path        = "tests/fixtures/connectivity-hosts"
    maintenance_enabled   = true
    cloudflare_account_id = "00000000000000000000000000000000"
    maintenance_hosts_override = jsonencode([
      { hostname = "maintenance-check.example.test", zone = "example.test", site = "mx", canary = true },
      { hostname = "dns-only.example.test", zone = "example.test", site = "mx" }
    ])
    maintenance_external_dns_override = jsonencode({
      "dns-only.example.test" = [{ name = "dns-only.example.test", type = "A", proxied = true }]
    })
  }
  expect_failures = [
    cloudflare_workers_script.maintenance["page"],
    cloudflare_workers_script.maintenance["redirect"]
  ]
}
