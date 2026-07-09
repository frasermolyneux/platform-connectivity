# Zero-touch adoption of existing Cloudflare records.
#
# scripts/Export-CloudflareRecordIds.ps1 queries the Cloudflare API and writes
# cf/record_ids.json — a map keyed by the SAME slug as local.cloudflare_records,
# each value carrying { zone_id, record_id }. The import blocks below bind each
# existing record to its resource so `terraform apply` adopts rather than
# recreates. When the file is absent (e.g. before the export is run, or in the
# dev environment) the map is empty and no imports are attempted.

locals {
  cloudflare_record_ids_file = "${path.module}/../cf/record_ids.json"
  cloudflare_record_imports  = fileexists(local.cloudflare_record_ids_file) ? jsondecode(file(local.cloudflare_record_ids_file)) : {}

  cloudflare_managed_record_count = (
    length(local.cf_a_records) + length(local.cf_aaaa_records) + length(local.cf_cname_records) +
    length(local.cf_mx_records) + length(local.cf_txt_records) + length(local.cf_srv_records)
  )
}

# Safety guard: when Cloudflare records are managed but no import IDs are loaded, a
# bare apply would attempt to CREATE records that already exist in Cloudflare (causing
# duplicate/rejected records). Fail fast instead. Run scripts/Export-CloudflareRecordIds.ps1
# and commit cf/record_ids.json before applying.
resource "terraform_data" "cloudflare_import_guard" {
  lifecycle {
    precondition {
      condition     = local.cloudflare_managed_record_count == 0 || length(local.cloudflare_record_imports) > 0
      error_message = "Cloudflare records are managed but cf/record_ids.json is missing or empty. Run scripts/Export-CloudflareRecordIds.ps1 and commit cf/record_ids.json before applying, otherwise Terraform will attempt to create records that already exist in Cloudflare."
    }
  }
}

import {
  for_each = { for k, v in local.cloudflare_record_imports : k => v if v.type == "A" }
  to       = cloudflare_dns_record.a[each.key]
  id       = "${each.value.zone_id}/${each.value.record_id}"
}

import {
  for_each = { for k, v in local.cloudflare_record_imports : k => v if v.type == "AAAA" }
  to       = cloudflare_dns_record.aaaa[each.key]
  id       = "${each.value.zone_id}/${each.value.record_id}"
}

import {
  for_each = { for k, v in local.cloudflare_record_imports : k => v if v.type == "CNAME" }
  to       = cloudflare_dns_record.cname[each.key]
  id       = "${each.value.zone_id}/${each.value.record_id}"
}

import {
  for_each = { for k, v in local.cloudflare_record_imports : k => v if v.type == "MX" }
  to       = cloudflare_dns_record.mx[each.key]
  id       = "${each.value.zone_id}/${each.value.record_id}"
}

import {
  for_each = { for k, v in local.cloudflare_record_imports : k => v if v.type == "TXT" }
  to       = cloudflare_dns_record.txt[each.key]
  id       = "${each.value.zone_id}/${each.value.record_id}"
}

import {
  for_each = { for k, v in local.cloudflare_record_imports : k => v if v.type == "SRV" }
  to       = cloudflare_dns_record.srv[each.key]
  id       = "${each.value.zone_id}/${each.value.record_id}"
}
