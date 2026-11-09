locals {
  maintenance_hosts = var.maintenance_hosts_override != "" ? jsondecode(var.maintenance_hosts_override) : jsondecode(file("${path.module}/../maintenance/hosts.json"))
  maintenance_modes = var.maintenance_enabled ? toset(["page", "redirect"]) : toset([])
  maintenance_canary_hosts = [
    for host in local.maintenance_hosts : host if try(host.canary, false)
  ]
  maintenance_canary_host = try(one(local.maintenance_canary_hosts), null)
  maintenance_proxied_hosts = toset(flatten([
    for zone in values(local.active_cloudflare_zones) : [
      for record in try(zone.records, []) :
      record.name == "@" ? zone.name : "${record.name}.${zone.name}"
      if try(record.proxied, false) && contains(["A", "AAAA", "CNAME"], record.type)
    ]
  ]))
}

resource "cloudflare_workers_script" "maintenance" {
  for_each = local.maintenance_modes

  account_id         = var.cloudflare_account_id
  script_name        = "platform-maintenance-${each.key}"
  main_module        = "worker.mjs"
  content            = file("${path.module}/../maintenance/worker.mjs")
  compatibility_date = "2026-10-23"
  bindings = [
    { name = "HOSTS", type = "plain_text", text = jsonencode(local.maintenance_hosts) },
    { name = "MODE", type = "plain_text", text = each.key },
  ]

  lifecycle {
    prevent_destroy = true
    precondition {
      condition = (
        var.environment == "prd" && var.cloudflare_account_id != "" &&
        length(distinct([for host in local.maintenance_hosts : host.hostname])) == length(local.maintenance_hosts) &&
        length(local.maintenance_canary_hosts) == 1 &&
        alltrue([for host in local.maintenance_hosts :
          (contains(local.maintenance_proxied_hosts, host.hostname) || try(host.canary, false)) &&
          !contains(["mxstatus.io", "status.xtremeidiots.com"], host.hostname) &&
          !strcontains(host.hostname, "*") &&
          contains(["mx", "xi"], host.site) &&
          contains(keys(local.cloudflare_zone_ids), host.zone)
        ])
      )
      error_message = "Maintenance requires production, a Cloudflare account, exactly one canary host, and unique exact proxied hostnames in configured Cloudflare zones."
    }

  }
}

resource "cloudflare_workers_script" "maintenance_canary" {
  count              = var.maintenance_enabled ? 1 : 0
  account_id         = var.cloudflare_account_id
  script_name        = "platform-maintenance-canary"
  main_module        = "canary.mjs"
  content            = file("${path.module}/../maintenance/canary.mjs")
  compatibility_date = "2026-10-23"
}

resource "cloudflare_workers_custom_domain" "maintenance_canary" {
  count      = var.maintenance_enabled ? 1 : 0
  account_id = var.cloudflare_account_id
  hostname   = try(local.maintenance_canary_host.hostname, "")
  service    = cloudflare_workers_script.maintenance_canary[0].script_name
  zone_id    = try(local.cloudflare_zone_ids[local.maintenance_canary_host.zone], "")
}

output "maintenance_runtime" {
  description = "Approved hostname contract for the status traffic controller. Active routes are deliberately not Terraform resources."
  value = var.maintenance_enabled ? {
    version   = 1
    accountId = var.cloudflare_account_id
    scripts   = { for mode, script in cloudflare_workers_script.maintenance : mode => script.script_name }
    hosts = [
      for host in local.maintenance_hosts : {
        hostname = host.hostname
        site     = host.site
        zoneId   = local.cloudflare_zone_ids[host.zone]
        canary   = try(host.canary, false)
      }
    ]
  } : null
}
