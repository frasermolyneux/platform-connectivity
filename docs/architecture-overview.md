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
- **Cloudflare zones** use the flat schema (`records[]` with per-record `type`/`name`/`content`/`proxied`) and set `management` to either `external` or `terraform`. Missing `management` defaults to `external` for compatibility with existing definitions.

External Cloudflare zones retain a committed `zone_id`; Terraform manages only their configured records. Terraform-managed zones set `management` to `terraform` and omit `zone_id`. For these zones, Terraform manages:

- The zone and authoritative name servers
- DNSSEC when `dnssec_enabled` is omitted or `true`
- Baseline zone settings selected by `plan_profile` (`free` or `pro`) with optional per-zone `settings` overrides
- DNS records
- One zone-level custom firewall ruleset, unless `waf_custom_rules_enabled` is `false`

The shared custom firewall ruleset stays within Cloudflare Free limits. It blocks probes for common sensitive files and directories, and applies Managed Challenge to common automated WordPress administration probes. It intentionally does not deploy rate limiting, Bot Fight Mode, Cloudflare managed rulesets, regex expressions, or application-specific controls.

The Cloudflare provider authenticates with `var.cloudflare_api_token`, supplied in CI as `TF_VAR_cloudflare_api_token` from the `CLOUDFLARE_API_KEY` secret. Terraform-managed zones also require `var.cloudflare_account_id`; the real account ID is supplied outside source control.

Ownership is split the same way as Azure zones: platform-connectivity holds the bulk of the (otherwise unmanaged) records, while workloads may attach their own records to the same zone — Azure via RBAC, Cloudflare via a scoped token. Records owned by other stacks (e.g. platform-notifications ACS records on `xtremeidiots.com`) are carved out and never managed here.

The `dns_zones` output keeps the same shape for Azure, external Cloudflare, and Terraform-managed Cloudflare zones. Consumers continue to receive each zone's ID, name, name servers, and `dns_provider` without needing to know its ownership mode.

### Adopting Cloudflare resources

- `terraform/zones/*.json` is the managed source of truth for Cloudflare records. It was originally generated from the Cloudflare dashboard's BIND export during migration (capturing proxy state, normalised TTLs, SOA/apex-NS dropped, other stacks' records carved out); edit the JSON directly going forward.
- An existing zone moving to `management: terraform` (and into the protected `CLOUDFLARE_ADOPTED_ZONE_KEYS` set, with `adopt_existing: true`) is adopted through data-source-driven `import` blocks in `cloudflare_imports.tf`. The `cloudflare_zone`, `cloudflare_dns_records`, and `cloudflare_rulesets` data sources read the live zone at plan time and the import blocks bind each object by its discovered ID, so no identifiers are committed and adoption runs through the normal `deploy-prd` plan/apply. Records are declared in the zone JSON `records[]`: a record that also exists live is imported, one that does not is created, and an empty zone simply has no records to import.
- A `cloudflare_ruleset` owns the complete custom-rules phase, so an existing custom-firewall ruleset is imported (not recreated) and a plan-time precondition fails if more than one entrypoint ruleset exists; reconcile its rules into `cloudflare_waf.tf` before apply.
- Import blocks are idempotent no-ops once an object is in state, so they remain in place and coexist with day-2 record additions and removals. New domains created through Terraform are never imported.
- Cloudflare account, zone, DNSSEC, record, and ruleset identifiers are discovered at plan time by the data sources. Do not commit or guess them.
- The Cloudflare general managed ruleset ID `efb7b8c949ac4650a09736fc376e9aee` is not deployed by this stack. It is reserved as a possible future plan-specific extension after entitlement and desired behavior are verified.

### Backup mirroring

Setting `backup_to_azure: true` on a Cloudflare zone JSON additionally mirrors its records into a non-authoritative Azure DNS zone (a cold standby). Cutover is manual — repoint the registrar name servers to the Azure zone. Off by default.

### Subdomain delegation

`var.dns_delegations` delegates a subdomain from a Cloudflare parent zone to a new Azure DNS child zone: an `azurerm_dns_zone` child is created and `NS` records are added to the Cloudflare parent pointing at the child's name servers. Empty by default (mechanism only; no delegations configured yet).
