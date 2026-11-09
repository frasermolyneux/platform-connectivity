check "cloudflare_zone_management_values" {
  assert {
    condition = alltrue([
      for zone in values(local.cloudflare_zones) :
      contains(["external", "terraform"], try(zone.management, "external"))
    ])
    error_message = "Cloudflare zone management must be either 'external' or 'terraform'."
  }
}

resource "cloudflare_zone" "managed" {
  for_each = local.managed_cloudflare_zones

  account = {
    id = var.cloudflare_account_id
  }
  name = each.value.name
  type = try(each.value.zone_type, "full")

  lifecycle {
    prevent_destroy = true

    precondition {
      condition     = var.cloudflare_account_id != ""
      error_message = "cloudflare_account_id must be set when Terraform-managed Cloudflare zones are configured."
    }

    precondition {
      condition     = contains(keys(local.cloudflare_zone_setting_profiles), try(each.value.plan_profile, "free"))
      error_message = "Cloudflare zone ${each.value.name} uses unsupported plan_profile '${try(each.value.plan_profile, "free")}'. Supported profiles: ${join(", ", keys(local.cloudflare_zone_setting_profiles))}."
    }

    precondition {
      condition = alltrue([
        for record in try(each.value.records, []) :
        try(trimspace(record.key), "") != ""
      ])
      error_message = "Terraform-managed Cloudflare DNS records in ${each.value.name} require an explicit stable key."
    }
  }
}

resource "cloudflare_zone_dnssec" "managed" {
  for_each = local.managed_cloudflare_zones

  zone_id = cloudflare_zone.managed[each.key].id
  status  = try(each.value.dnssec_enabled, true) ? "active" : "disabled"
}

resource "cloudflare_zone_setting" "managed" {
  for_each = local.managed_cloudflare_zone_settings

  zone_id    = cloudflare_zone.managed[each.value.zone_key].id
  setting_id = each.value.setting_id
  value      = each.value.value
}
