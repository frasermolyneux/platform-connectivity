# ---------------------------------------------------------------------------
# Data-source-driven adoption of existing Cloudflare zones.
#
# When a zone is activated via cloudflare_adopted_zone_keys, these data sources
# read the live zone, its DNS records, and any existing custom-firewall ruleset
# at plan time. The import blocks below bind each existing object to its
# Terraform resource using IDs discovered from those reads, so adoption runs
# through the normal deploy-prd plan/apply with no identifiers committed to
# source and no bespoke workflow.
#
# Records are declared as desired state in the zone JSON (records[]). A record
# listed there that also exists live is imported (bound by the ID the
# cloudflare_dns_records data source discovers); one not yet live is created; an
# empty zone has nothing to import. Import blocks are idempotent no-ops once a
# resource is in state, so they stay in place and coexist with day-2 changes.
# ---------------------------------------------------------------------------

data "cloudflare_zone" "adopt" {
  for_each = local.cloudflare_zones_to_adopt

  filter = {
    name = each.value.name
  }
}

data "cloudflare_dns_records" "adopt" {
  for_each = local.cloudflare_zones_to_adopt

  zone_id = data.cloudflare_zone.adopt[each.key].zone_id
}

data "cloudflare_rulesets" "adopt" {
  for_each = {
    for k, z in local.cloudflare_zones_to_adopt : k => z
    if try(z.waf_custom_rules_enabled, true)
  }

  zone_id = data.cloudflare_zone.adopt[each.key].zone_id
}

locals {
  # Adopt-existing zones read the live zone and import its objects. New domains
  # (adopt_existing absent/false) are created fresh with no data-source read, so
  # the data sources above never target a zone that does not yet exist.
  cloudflare_zones_to_adopt = { for k, z in local.managed_cloudflare_zones : k => z if try(z.adopt_existing, false) }

  # Live records keyed with the same slugs the cloudflare_dns_record.* resources
  # use, so desired-state (JSON) and live objects line up for import.
  # Cloudflare returns FQDN record names; the zone JSON uses the relative form
  # (@ for apex). Normalise live names to the relative form so keys align.
  cf_live_records_by_content = length(local.cloudflare_zones_to_adopt) > 0 ? merge([
    for k, zone in local.cloudflare_zones_to_adopt : {
      for r in data.cloudflare_dns_records.adopt[k].result :
      "${zone.name}|${r.type}|${r.name == zone.name ? "@" : trimsuffix(r.name, ".${zone.name}")}|${r.content}" => {
        zone_id   = data.cloudflare_zone.adopt[k].zone_id
        record_id = r.id
      } if contains(["A", "AAAA", "CNAME", "MX", "TXT"], r.type)
    }
  ]...) : {}

  cf_live_srv_records = length(local.cloudflare_zones_to_adopt) > 0 ? merge([
    for k, zone in local.cloudflare_zones_to_adopt : {
      for r in data.cloudflare_dns_records.adopt[k].result :
      "${zone.name}|SRV|${r.name == zone.name ? "@" : trimsuffix(r.name, ".${zone.name}")}|${try(r.data.target, "")}:${try(r.data.port, "")}" => {
        zone_id   = data.cloudflare_zone.adopt[k].zone_id
        record_id = r.id
      } if r.type == "SRV"
    }
  ]...) : {}

  # Per-type import maps: config key => "<zone_id>/<record_id>", only where the
  # config record also exists live. Records present in config but not live are
  # created by the normal plan rather than imported.
  cf_import_a     = { for key in keys(local.cf_a_records) : key => "${local.cf_live_records_by_content[key].zone_id}/${local.cf_live_records_by_content[key].record_id}" if contains(keys(local.cf_live_records_by_content), key) }
  cf_import_aaaa  = { for key in keys(local.cf_aaaa_records) : key => "${local.cf_live_records_by_content[key].zone_id}/${local.cf_live_records_by_content[key].record_id}" if contains(keys(local.cf_live_records_by_content), key) }
  cf_import_cname = { for key in keys(local.cf_cname_records) : key => "${local.cf_live_records_by_content[key].zone_id}/${local.cf_live_records_by_content[key].record_id}" if contains(keys(local.cf_live_records_by_content), key) }
  cf_import_mx    = { for key in keys(local.cf_mx_records) : key => "${local.cf_live_records_by_content[key].zone_id}/${local.cf_live_records_by_content[key].record_id}" if contains(keys(local.cf_live_records_by_content), key) }
  cf_import_txt   = { for key in keys(local.cf_txt_records) : key => "${local.cf_live_records_by_content[key].zone_id}/${local.cf_live_records_by_content[key].record_id}" if contains(keys(local.cf_live_records_by_content), key) }
  cf_import_srv   = { for key in keys(local.cf_srv_records) : key => "${local.cf_live_srv_records[key].zone_id}/${local.cf_live_srv_records[key].record_id}" if contains(keys(local.cf_live_srv_records), key) }

  # Existing zone custom-firewall ruleset (at most one per zone/phase) to adopt
  # rather than recreate. Absent when the zone has no such ruleset yet.
  cf_waf_ruleset_ids = {
    for k, z in local.cloudflare_zones_to_adopt :
    k => [for r in data.cloudflare_rulesets.adopt[k].result : r.id if r.phase == "http_request_firewall_custom" && r.kind == "zone"]
    if try(z.waf_custom_rules_enabled, true)
  }

  cf_waf_import = {
    for k, ids in local.cf_waf_ruleset_ids :
    k => "zones/${data.cloudflare_zone.adopt[k].zone_id}/${ids[0]}"
    if length(ids) == 1
  }
}

import {
  for_each = local.cloudflare_zones_to_adopt
  to       = cloudflare_zone.managed[each.key]
  id       = data.cloudflare_zone.adopt[each.key].zone_id
}

import {
  for_each = { for k, z in local.cloudflare_zones_to_adopt : k => z if try(z.dnssec_enabled, true) }
  to       = cloudflare_zone_dnssec.managed[each.key]
  id       = data.cloudflare_zone.adopt[each.key].zone_id
}

import {
  for_each = { for key, s in local.managed_cloudflare_zone_settings : key => s if contains(keys(local.cloudflare_zones_to_adopt), s.zone_key) }
  to       = cloudflare_zone_setting.managed[each.key]
  id       = "${data.cloudflare_zone.adopt[each.value.zone_key].zone_id}/${each.value.setting_id}"
}

import {
  for_each = local.cf_waf_import
  to       = cloudflare_ruleset.zone_custom_firewall[each.key]
  id       = each.value
}

import {
  for_each = local.cf_import_a
  to       = cloudflare_dns_record.a[each.key]
  id       = each.value
}

import {
  for_each = local.cf_import_aaaa
  to       = cloudflare_dns_record.aaaa[each.key]
  id       = each.value
}

import {
  for_each = local.cf_import_cname
  to       = cloudflare_dns_record.cname[each.key]
  id       = each.value
}

import {
  for_each = local.cf_import_mx
  to       = cloudflare_dns_record.mx[each.key]
  id       = each.value
}

import {
  for_each = local.cf_import_txt
  to       = cloudflare_dns_record.txt[each.key]
  id       = each.value
}

import {
  for_each = local.cf_import_srv
  to       = cloudflare_dns_record.srv[each.key]
  id       = each.value
}
