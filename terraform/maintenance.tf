locals {
  maintenance_hosts = jsondecode(file("${path.module}/../maintenance/hosts.json"))
  maintenance_modes = var.maintenance_enabled ? toset(["page", "redirect"]) : toset([])
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
        alltrue([for host in local.maintenance_hosts :
          (contains(local.maintenance_proxied_hosts, host.hostname) || try(host.canary, false) && host.hostname == "maintenance-check.bishopsbees.co.uk") &&
          !contains(["mxstatus.io", "status.xtremeidiots.com"], host.hostname) &&
          !strcontains(host.hostname, "*") &&
          contains(["mx", "xi"], host.site)
        ])
      )
      error_message = "Maintenance requires production, a Cloudflare account, and unique exact proxied hostnames excluding status sites."
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
  hostname   = "maintenance-check.bishopsbees.co.uk"
  service    = cloudflare_workers_script.maintenance_canary[0].script_name
  zone_id    = local.cloudflare_zone_ids["bishopsbees.co.uk"]
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
