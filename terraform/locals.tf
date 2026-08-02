locals {
  dns_resource_group_name = "rg-platform-dns-${var.environment}-${var.location}-${var.instance}"

  # ---------------------------------------------------------------------------
  # Load and classify DNS zone JSON files
  #
  # Azure-managed zones use the grouped schema (a_records/cname_records/...).
  # Cloudflare-managed zones use the flat schema (records[] with per-record
  # type/name/content/proxied), plus a zone_id and a backup_to_azure flag.
  # ---------------------------------------------------------------------------
  dns_zone_files = var.dns_zones_path != "" ? fileset(var.dns_zones_path, "*.json") : []
  all_zones = {
    for file in local.dns_zone_files :
    trimsuffix(file, ".json") => jsondecode(file("${var.dns_zones_path}/${file}"))
  }

  azure_native_zones = { for k, z in local.all_zones : k => z if try(z.dns_provider, "azure") == "azure" }
  cloudflare_zones   = { for k, z in local.all_zones : k => z if try(z.dns_provider, "azure") == "cloudflare" }

  declared_managed_cloudflare_zones = { for k, z in local.cloudflare_zones : k => z if try(z.management, "external") == "terraform" }
  managed_cloudflare_zones = {
    for k, z in local.declared_managed_cloudflare_zones : k => z
    if contains(var.cloudflare_adopted_zone_keys, k)
  }
  legacy_cloudflare_zones = { for k, z in local.cloudflare_zones : k => z if try(z.management, "external") == "external" }
  active_cloudflare_zones = merge(local.legacy_cloudflare_zones, local.managed_cloudflare_zones)

  cloudflare_zone_setting_profiles = {
    free = {
      always_use_https         = "on"
      automatic_https_rewrites = "on"
      brotli                   = "on"
      browser_check            = "on"
      http2                    = "on"
      http3                    = "on"
      ipv6                     = "on"
      min_tls_version          = "1.2"
      security_level           = "medium"
      ssl                      = "strict"
      tls_1_3                  = "on"
    }
    pro = {
      always_use_https         = "on"
      automatic_https_rewrites = "on"
      brotli                   = "on"
      browser_check            = "on"
      http2                    = "on"
      http3                    = "on"
      ipv6                     = "on"
      min_tls_version          = "1.2"
      security_level           = "medium"
      ssl                      = "strict"
      tls_1_3                  = "on"
    }
  }

  managed_cloudflare_zone_settings = merge([
    for zone_key, zone in local.managed_cloudflare_zones : {
      for setting_id, value in merge(
        lookup(local.cloudflare_zone_setting_profiles, try(zone.plan_profile, "free"), {}),
        try(zone.settings, {})
        ) : "${zone_key}/${setting_id}" => {
        zone_key   = zone_key
        setting_id = setting_id
        value      = value
      }
    }
  ]...)

  # Name -> zone_id lookup for all Cloudflare zones (used by records, delegation, and outputs).
  cloudflare_zone_ids = merge(
    { for k, z in local.legacy_cloudflare_zones : z.name => z.zone_id },
    { for k, z in cloudflare_zone.managed : z.name => z.id }
  )

  # ---------------------------------------------------------------------------
  # Backup mirroring: reshape a Cloudflare (flat) zone into the grouped Azure
  # schema so it can be duplicated into a non-authoritative Azure DNS zone when
  # backup_to_azure = true. Cloudflare TTL 1 ("automatic") is normalised to 300s.
  # ---------------------------------------------------------------------------
  cloudflare_backup_zones = { for k, z in local.active_cloudflare_zones : k => z if try(z.backup_to_azure, false) }

  cloudflare_backup_reshaped = {
    for k, z in local.cloudflare_backup_zones : k => {
      name         = z.name
      dns_provider = "azure"
      a_records = [
        for nm in distinct([for r in z.records : r.name if r.type == "A"]) : {
          name    = nm
          ttl     = [for r in z.records : (try(r.ttl, 300) == 1 ? 300 : try(r.ttl, 300)) if r.type == "A" && r.name == nm][0]
          records = [for r in z.records : r.content if r.type == "A" && r.name == nm]
        }
      ]
      aaaa_records = [
        for nm in distinct([for r in z.records : r.name if r.type == "AAAA"]) : {
          name    = nm
          ttl     = [for r in z.records : (try(r.ttl, 300) == 1 ? 300 : try(r.ttl, 300)) if r.type == "AAAA" && r.name == nm][0]
          records = [for r in z.records : r.content if r.type == "AAAA" && r.name == nm]
        }
      ]
      cname_records = [
        for r in z.records : {
          name   = r.name
          ttl    = try(r.ttl, 300) == 1 ? 300 : try(r.ttl, 300)
          record = r.content
        } if r.type == "CNAME"
      ]
      mx_records = [
        for nm in distinct([for r in z.records : r.name if r.type == "MX"]) : {
          name    = nm
          ttl     = [for r in z.records : (try(r.ttl, 300) == 1 ? 300 : try(r.ttl, 300)) if r.type == "MX" && r.name == nm][0]
          records = [for r in z.records : { preference = r.priority, exchange = r.content } if r.type == "MX" && r.name == nm]
        }
      ]
      txt_records = [
        for nm in distinct([for r in z.records : r.name if r.type == "TXT"]) : {
          name    = nm
          ttl     = [for r in z.records : (try(r.ttl, 300) == 1 ? 300 : try(r.ttl, 300)) if r.type == "TXT" && r.name == nm][0]
          records = [for r in z.records : r.content if r.type == "TXT" && r.name == nm]
        }
      ]
      srv_records = [
        for nm in distinct([for r in z.records : r.name if r.type == "SRV"]) : {
          name    = nm
          ttl     = [for r in z.records : (try(r.ttl, 300) == 1 ? 300 : try(r.ttl, 300)) if r.type == "SRV" && r.name == nm][0]
          records = [for r in z.records : r.data if r.type == "SRV" && r.name == nm]
        }
      ]
    }
  }

  # Azure DNS zones to build = Azure-native zones + Cloudflare zones flagged for backup.
  # The azurerm_dns_zone and per-record resources consume this map unchanged.
  dns_zones = merge(local.azure_native_zones, local.cloudflare_backup_reshaped)

  # Flatten all records across all zones for each record type
  a_records = length(local.dns_zones) > 0 ? merge([
    for zone_key, zone in local.dns_zones : {
      for record in try(zone.a_records, []) :
      "${zone.name}/${record.name}" => {
        zone_key  = zone_key
        zone_name = zone.name
        name      = record.name
        ttl       = try(record.ttl, 3600)
        records   = record.records
      }
    }
  ]...) : {}

  aaaa_records = length(local.dns_zones) > 0 ? merge([
    for zone_key, zone in local.dns_zones : {
      for record in try(zone.aaaa_records, []) :
      "${zone.name}/${record.name}" => {
        zone_key  = zone_key
        zone_name = zone.name
        name      = record.name
        ttl       = try(record.ttl, 3600)
        records   = record.records
      }
    }
  ]...) : {}

  cname_records = length(local.dns_zones) > 0 ? merge([
    for zone_key, zone in local.dns_zones : {
      for record in try(zone.cname_records, []) :
      "${zone.name}/${record.name}" => {
        zone_key  = zone_key
        zone_name = zone.name
        name      = record.name
        ttl       = try(record.ttl, 3600)
        record    = record.record
      }
    }
  ]...) : {}

  mx_records = length(local.dns_zones) > 0 ? merge([
    for zone_key, zone in local.dns_zones : {
      for record in try(zone.mx_records, []) :
      "${zone.name}/${record.name}" => {
        zone_key  = zone_key
        zone_name = zone.name
        name      = record.name
        ttl       = try(record.ttl, 3600)
        records   = record.records
      }
    }
  ]...) : {}

  txt_records = length(local.dns_zones) > 0 ? merge([
    for zone_key, zone in local.dns_zones : {
      for record in try(zone.txt_records, []) :
      "${zone.name}/${record.name}" => {
        zone_key  = zone_key
        zone_name = zone.name
        name      = record.name
        ttl       = try(record.ttl, 3600)
        records   = record.records
      }
    }
  ]...) : {}

  srv_records = length(local.dns_zones) > 0 ? merge([
    for zone_key, zone in local.dns_zones : {
      for record in try(zone.srv_records, []) :
      "${zone.name}/${record.name}" => {
        zone_key    = zone_key
        zone_name   = zone.name
        name        = record.name
        ttl         = try(record.ttl, 3600)
        records     = record.records
        skip_import = try(record.skip_import, false)
      }
    }
  ]...) : {}

  # ---------------------------------------------------------------------------
  # Cloudflare DNS records — one homogeneous map per record type (mirrors the
  # Azure per-type locals). Keyed by stable zone-qualified slugs.
  # ---------------------------------------------------------------------------
  cf_a_records = length(local.active_cloudflare_zones) > 0 ? merge([
    for zk, z in local.active_cloudflare_zones : {
      for r in z.records : "${z.name}|A|${r.name}|${r.content}" => {
        zone_id = local.cloudflare_zone_ids[z.name]
        name    = r.name
        ttl     = try(r.ttl, 1)
        content = r.content
        proxied = try(r.proxied, false)
      } if r.type == "A"
    }
  ]...) : {}

  cf_aaaa_records = length(local.active_cloudflare_zones) > 0 ? merge([
    for zk, z in local.active_cloudflare_zones : {
      for r in z.records : "${z.name}|AAAA|${r.name}|${r.content}" => {
        zone_id = local.cloudflare_zone_ids[z.name]
        name    = r.name
        ttl     = try(r.ttl, 1)
        content = r.content
        proxied = try(r.proxied, false)
      } if r.type == "AAAA"
    }
  ]...) : {}

  cf_cname_records = length(local.active_cloudflare_zones) > 0 ? merge([
    for zk, z in local.active_cloudflare_zones : {
      for r in z.records : "${z.name}|CNAME|${r.name}|${r.content}" => {
        zone_id = local.cloudflare_zone_ids[z.name]
        name    = r.name
        ttl     = try(r.ttl, 1)
        content = r.content
        proxied = try(r.proxied, false)
      } if r.type == "CNAME"
    }
  ]...) : {}

  cf_mx_records = length(local.active_cloudflare_zones) > 0 ? merge([
    for zk, z in local.active_cloudflare_zones : {
      for r in z.records : "${z.name}|MX|${r.name}|${r.content}" => {
        zone_id  = local.cloudflare_zone_ids[z.name]
        name     = r.name
        ttl      = try(r.ttl, 1)
        content  = r.content
        priority = r.priority
      } if r.type == "MX"
    }
  ]...) : {}

  cf_txt_records = length(local.active_cloudflare_zones) > 0 ? merge([
    for zk, z in local.active_cloudflare_zones : {
      for r in z.records : "${z.name}|TXT|${r.name}|${r.content}" => {
        zone_id = local.cloudflare_zone_ids[z.name]
        name    = r.name
        ttl     = try(r.ttl, 1)
        content = r.content
      } if r.type == "TXT"
    }
  ]...) : {}

  cf_srv_records = length(local.active_cloudflare_zones) > 0 ? merge([
    for zk, z in local.active_cloudflare_zones : {
      for r in z.records : "${z.name}|SRV|${r.name}|${r.data.target}:${r.data.port}" => {
        zone_id = local.cloudflare_zone_ids[z.name]
        name    = r.name
        ttl     = try(r.ttl, 1)
        data    = r.data
      } if r.type == "SRV"
    }
  ]...) : {}

  # ---------------------------------------------------------------------------
  # Subdomain delegation from a Cloudflare parent zone to an Azure DNS child zone.
  # Empty by default (var.dns_delegations = []). Azure public zones always return
  # four name servers, so NS records are created for indices 0..3.
  # ---------------------------------------------------------------------------
  delegations = { for d in var.dns_delegations : "${d.subdomain}.${d.parent_zone}" => d }

  delegation_ns = length(local.delegations) > 0 ? merge([
    for k, d in local.delegations : {
      for i in range(4) : "${k}/${i}" => {
        delegation  = k
        subdomain   = d.subdomain
        parent_zone = d.parent_zone
        index       = i
      }
    }
  ]...) : {}

  # Load private link zones
  private_link_zones = var.private_link_zones_file != "" ? jsondecode(file(var.private_link_zones_file)) : []
}
