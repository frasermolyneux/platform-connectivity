locals {
  dns_resource_group_name = "rg-platform-dns-${var.environment}-${var.location}-${var.instance}"

  # Load DNS zone JSON files
  dns_zone_files = var.dns_zones_path != "" ? fileset(var.dns_zones_path, "*.json") : []
  dns_zones = {
    for file in local.dns_zone_files :
    trimsuffix(file, ".json") => jsondecode(file("${var.dns_zones_path}/${file}"))
  }

  # Flatten all records across all zones for each record type
  a_records = length(local.dns_zones) > 0 ? merge([
    for zone_key, zone in local.dns_zones : {
      for record in try(zone.a_records, []) :
      "${zone.name}/${record.name}" => {
        zone_key    = zone_key
        zone_name   = zone.name
        name        = record.name
        ttl         = try(record.ttl, 3600)
        records     = record.records
      }
    }
  ]...) : {}

  aaaa_records = length(local.dns_zones) > 0 ? merge([
    for zone_key, zone in local.dns_zones : {
      for record in try(zone.aaaa_records, []) :
      "${zone.name}/${record.name}" => {
        zone_key    = zone_key
        zone_name   = zone.name
        name        = record.name
        ttl         = try(record.ttl, 3600)
        records     = record.records
      }
    }
  ]...) : {}

  cname_records = length(local.dns_zones) > 0 ? merge([
    for zone_key, zone in local.dns_zones : {
      for record in try(zone.cname_records, []) :
      "${zone.name}/${record.name}" => {
        zone_key    = zone_key
        zone_name   = zone.name
        name        = record.name
        ttl         = try(record.ttl, 3600)
        record      = record.record
      }
    }
  ]...) : {}

  mx_records = length(local.dns_zones) > 0 ? merge([
    for zone_key, zone in local.dns_zones : {
      for record in try(zone.mx_records, []) :
      "${zone.name}/${record.name}" => {
        zone_key    = zone_key
        zone_name   = zone.name
        name        = record.name
        ttl         = try(record.ttl, 3600)
        records     = record.records
      }
    }
  ]...) : {}

  txt_records = length(local.dns_zones) > 0 ? merge([
    for zone_key, zone in local.dns_zones : {
      for record in try(zone.txt_records, []) :
      "${zone.name}/${record.name}" => {
        zone_key    = zone_key
        zone_name   = zone.name
        name        = record.name
        ttl         = try(record.ttl, 3600)
        records     = record.records
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
      }
    }
  ]...) : {}

  # Load private link zones
  private_link_zones = var.private_link_zones_file != "" ? jsondecode(file(var.private_link_zones_file)) : []
}
