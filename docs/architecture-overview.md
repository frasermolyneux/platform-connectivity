# Architecture Overview

This repository deploys tenant platform connectivity resources using Terraform.

- A DNS resource group is created per environment/location/instance using the pattern `rg-platform-dns-{environment}-{location}-{instance}`.
- Private DNS zones are provisioned only for production and cover common Azure private endpoints (storage, SQL, ACR, App Service, Service Bus, API Management, etc.). The zone list is defined in `terraform/private_link_zones/prd.json`.
- Public DNS zones for platform domains (e.g., molyneux.dev, molyneux.io, xtremeidiots.com, xtremeidiots.dev, geo-location.net, molyneux.me, molyneux-consulting.co.uk, mx-consulting.co.uk) are deployed for production. Each domain is defined as a JSON file under `terraform/zones/` containing the zone name and all its DNS records.
- Terraform dynamically loads zone JSON files and creates `azurerm_dns_zone`, record resources (A, AAAA, CNAME, MX, TXT, SRV), and `azurerm_private_dns_zone` resources.
- Environment gating is achieved via tfvars: dev has no `dns_zones_path` set (empty resource group only), while prd points to the zone configurations.
- Remote state from `platform-workloads` is consumed for workload resource group metadata.
- Tags are applied from tfvars, typically including `Environment`, `Workload`, `DeployedBy`, and `Git` for traceability.

## DNS providers: Azure and Cloudflare

Each zone JSON declares a `dns_provider` of either `azure` (default) or `cloudflare`:

- **Azure-managed zones** use the grouped schema (`a_records`, `cname_records`, ...) and are provisioned as `azurerm_dns_zone` + record resources.
- **Cloudflare-managed zones** use the flat schema (`records[]` with per-record `type`/`name`/`content`/`proxied`), plus a `zone_id` and a `backup_to_azure` flag. They are provisioned as `cloudflare_dns_record` resources against the existing Cloudflare zone (referenced by `zone_id`; the zone itself is not created by Terraform). The Cloudflare provider authenticates with `var.cloudflare_api_token` (supplied in CI as `TF_VAR_cloudflare_api_token` from the `CLOUDFLARE_API_KEY` secret).

Ownership is split the same way as Azure zones: platform-connectivity holds the bulk of the (otherwise unmanaged) records, while workloads may attach their own records to the same zone — Azure via RBAC, Cloudflare via a scoped token. Records owned by other stacks (e.g. platform-notifications ACS records on `xtremeidiots.com`) are carved out and never managed here.

### Adopting Cloudflare records

- `terraform/zones/*.json` is the managed source of truth for Cloudflare records. It was originally generated from the Cloudflare dashboard's BIND export during migration (capturing proxy state, normalised TTLs, SOA/apex-NS dropped, other stacks' records carved out); edit the JSON directly going forward.
- `scripts/Export-CloudflareRecordIds.ps1` queries the Cloudflare API and writes `cf/record_ids.json`, mapping each managed record to its Cloudflare record ID. `terraform/cloudflare_dns_imports.tf` uses this to `import` existing records so `apply` adopts rather than recreates them. When the file is absent, no imports are attempted. Once the initial adoption apply has succeeded, the import blocks, `cf/record_ids.json`, and this script can be removed.

### Backup mirroring

Setting `backup_to_azure: true` on a Cloudflare zone JSON additionally mirrors its records into a non-authoritative Azure DNS zone (a cold standby). Cutover is manual — repoint the registrar name servers to the Azure zone. Off by default.

### Subdomain delegation

`var.dns_delegations` delegates a subdomain from a Cloudflare parent zone to a new Azure DNS child zone: an `azurerm_dns_zone` child is created and `NS` records are added to the Cloudflare parent pointing at the child's name servers. Empty by default (mechanism only; no delegations configured yet).
