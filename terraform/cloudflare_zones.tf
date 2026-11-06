check "cloudflare_zone_management_values" {
  assert {
    condition = alltrue([
      for zone in values(local.cloudflare_zones) :
      contains(["external", "terraform"], try(zone.management, "external"))
    ])
    error_message = "Cloudflare zone management must be either 'external' or 'terraform'."
  }
}

check "cloudflare_adopted_zone_keys" {
  assert {
    condition     = length(setsubtract(var.cloudflare_adopted_zone_keys, toset(keys(local.declared_managed_cloudflare_zones)))) == 0
    error_message = "cloudflare_adopted_zone_keys may only contain zone keys declared with management set to terraform."
  }
}

resource "terraform_data" "pending_cloudflare_adoption" {
  for_each = local.pending_cloudflare_adoptions

  input = each.value.name

  lifecycle {
    precondition {
      condition     = try(trimspace(each.value.zone_id) != "", false)
      error_message = "Existing Cloudflare zone ${each.value.name} must retain its external zone_id while adoption is pending, so its records remain managed."
    }
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
  }
}

resource "cloudflare_zone_dnssec" "managed" {
  for_each = {
    for key, zone in local.managed_cloudflare_zones : key => zone
    if try(zone.dnssec_enabled, true)
  }

  zone_id = cloudflare_zone.managed[each.key].id
  status  = "active"
}

resource "cloudflare_zone_setting" "managed" {
  for_each = local.managed_cloudflare_zone_settings

  zone_id    = cloudflare_zone.managed[each.value.zone_key].id
  setting_id = each.value.setting_id
  value      = each.value.value
}
