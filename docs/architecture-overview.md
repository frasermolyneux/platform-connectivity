# Architecture Overview

This repository deploys tenant platform connectivity resources using Terraform.

- A DNS resource group is created per environment/location/instance using the pattern `rg-platform-dns-{environment}-{location}-{instance}`.
- Private DNS zones are provisioned only for production and cover common Azure private endpoints (storage, SQL, ACR, App Service, Service Bus, API Management, etc.). The zone list is defined in `terraform/private_link_zones/prd.json`.
- Public DNS desired state is defined in `terraform/zones/`; each JSON file contains a zone and the records owned by this stack, not necessarily every record in the zone.
- Terraform loads those files to manage Azure and Cloudflare zones and records; Azure Private Link zones come from the separate private-zone list.
- Environment gating is configured in `terraform/tfvars/`: dev creates only the DNS resource group, while prd enables public zones, Private Link zones and maintenance Workers.
- Remote state from `platform-workloads` is consumed for workload resource group metadata.
- Tags are applied from tfvars, typically including `Environment`, `Workload`, `DeployedBy`, and `Git` for traceability.

## DNS providers: Azure and Cloudflare

Each zone JSON declares a `dns_provider` of either `azure` (default) or `cloudflare`:

- **Azure-managed zones** use the grouped schema (`a_records`, `cname_records`, ...) and are provisioned as `azurerm_dns_zone` + record resources.
- **Cloudflare zones** use the flat schema (`records[]` with per-record `type`/`name`/`content`/`proxied`) and set `management` to either `external` or `terraform`. Missing `management` defaults to `external` for compatibility with existing definitions.

External Cloudflare zones retain a committed `zone_id`; Terraform manages their configured records and any explicitly enabled hostname origin TLS overrides below, not their zone-wide settings. Zone JSON ownership is authoritative: zones awaiting adoption remain `management: external` until the handoff is separately approved. Terraform-managed zones set `management` to `terraform`; existing zones also set `adopt_existing: true` to use their discovered ID, while new zones are created. For these zones, Terraform manages:

- The zone and authoritative name servers
- DNSSEC status from `dnssec_enabled` (defaults to enabled)
- Baseline zone settings selected by `plan_profile` (`free` or `pro`) with optional per-zone `settings` overrides
- DNS records
- One zone-level custom firewall ruleset, unless `waf_custom_rules_enabled` is `false`
- Additional phase-keyed zone rulesets declared in `rulesets`, and legacy Page Rules declared in `page_rules`

The shared default custom firewall ruleset stays within Cloudflare Free limits. It blocks probes for common sensitive files and directories, and applies Managed Challenge to common automated WordPress administration probes. Zone-specific rulesets are declared by Cloudflare phase in `rulesets`; they can preserve managed-WAF execution, rate limiting, or redirects without changing the shared default rules.

All 18 inventoried Cloudflare zones are configured for preservation-first
management; see the [estate ownership matrix](cloudflare-estate-ownership.md).
Their settings snapshots record every setting the zone API marked editable
and retain previously owned read-only settings. The `xtremeidiots.com`
custom-firewall snapshot preserves the existing rules in order, including AI
Crawl Control. With `waf_preserve_existing`, adoption requires one existing
custom-firewall entrypoint matching the reviewed snapshot and uses rule
references discovered at plan time. Drift fails the precondition; this is a
preservation guard, not a way to deploy changes to that ruleset. Cloudflare AI
Crawl Control can also edit this phase, so coordinate its management before any
later change.

The zone's existing managed-WAF, rate-limit, redirect, and legacy Page Rules
are also declared as configuration and imported without intentionally changing
their behavior. Only active zone-level rulesets are adopted; managed-ruleset
catalog entries are not deployments. The `http_config_settings` phase remains
owned by `platform-status-web`, and active maintenance routes remain controlled
by the runtime controller. Platform-notifications-owned ACS/SPF DNS records are
carved out. Do not manage or import any of these delegated resources here.

Terraform-managed Cloudflare records require a non-empty, per-type `key` in
`records[]`; resource addresses use that key rather than mutable DNS content.
When changing an already-managed record from the legacy content-derived address,
add a declarative `moved` block using the exact address read from the relevant
Terraform state. Do not use imperative state moves. The import matcher still
uses the full DNS data, including SRV priority and weight, to bind the intended
live record.

New zones may inherit the selected setting profile. An adopted zone must include
an explicit settings snapshot and `settings_preserve_existing: true`; profile
defaults are not merged into that snapshot. Unsupported Cloudflare DNS record
types fail the plan until explicit resource and import support is implemented.
An adopted zone's configured Page Rule or phase ruleset is imported when one
unambiguous matching object exists, and created when none exists. Ambiguity,
API errors, or a same-target Page Rule that differs from its reviewed
configuration fail closed. Existing custom-firewall entrypoints require an
explicit preservation snapshot and fail if absent, ambiguous, unreadable, or
different.

The Cloudflare provider authenticates with `var.cloudflare_api_token`, supplied in CI as `TF_VAR_cloudflare_api_token` from the `CLOUDFLARE_API_KEY` secret. Terraform-managed zones also require `var.cloudflare_account_id`; the real account ID is supplied outside source control.

Ownership is split the same way as Azure zones: platform-connectivity holds the bulk of the (otherwise unmanaged) records, while workloads may attach their own records to the same zone — Azure via RBAC, Cloudflare via a scoped token. Records owned by other stacks (e.g. platform-notifications ACS records on `xtremeidiots.com`) are carved out and never managed here.

The `dns_zones` output uses a common shape across providers. Cloudflare zones
without an Azure backup report Cloudflare as their provider; external zones
have no name servers populated by this output. When backup mirroring is enabled,
the output instead describes the Azure backup zone. See `terraform/outputs.tf`
for the contract.

### Hostname origin TLS overrides

An explicit `origin_tls_hostnames` list opts an existing external zone into one shared
`http_config_settings` entrypoint that sets Full (strict) origin TLS only for
those exact, declared proxied record hostnames. This is available without
adopting the zone or changing its default SSL mode, so existing HTTP/HTTPS
workloads remain unaffected. The deployment token needs `Config Settings Write`
only for opted-in zones; the runtime DNS-01 credential does not.

On adoption, `origin_tls_preserve_existing: true` retains an already-owned
entrypoint at its existing address and identity. It does not import another
stack's entrypoint or change the zone-wide SSL snapshot. Without this explicit
preservation flag, Terraform-managed zones reject the opt-in. The existing
owner-identity check still rejects a competing entrypoint.

Wildcards, undeclared/unproxied hostnames and duplicate entries are rejected.
Ownership uses a unique `terraform_data` identity retained in this state, not a
shared display name. An existing configuration entrypoint without that identity
blocks creation: coordinate reviewed preservation/adoption with its owner.
If the ruleset binding alone is lost, a data-source-driven import rebinds only
the entrypoint matching the retained identity, rather than creating a replacement.
Losing the ownership identity itself fails closed and requires reviewed recovery.
Workload-owned configuration phases remain outside this stack. Destruction of
the managed origin TLS entrypoint is protected and requires explicit review.

### Adopting Cloudflare resources

- `terraform/zones/*.json` is the managed source of truth for Cloudflare records. It was originally generated from the Cloudflare dashboard's BIND export during migration (capturing proxy state, normalised TTLs, SOA/apex-NS dropped, other stacks' records carved out); edit the JSON directly going forward.
- An existing zone moving to `management: terraform` with `adopt_existing: true` is adopted through data-source-driven `import` blocks in `cloudflare_imports.tf`. The `cloudflare_zone`, `cloudflare_dns_records`, and `cloudflare_rulesets` data sources read the live zone at plan time and the import blocks bind each object by its discovered ID, so no identifiers are committed and adoption runs through the normal `deploy-prd` plan/apply. Records are declared in the zone JSON `records[]`: a record that also exists live is imported, one that does not is created, and an empty zone simply has no records to import.
- A `cloudflare_ruleset` owns each configured zone-level phase. Existing custom-firewall rulesets use the reviewed preservation snapshot; other configured rulesets and legacy Page Rules use data-source-driven imports and preserve their rule order, actions, and enabled state.
- Import blocks are idempotent no-ops once an object is in state, so they remain in place and coexist with day-2 record additions and removals. New domains created through Terraform are never imported.
- The zone JSON `management` declaration is the ownership gate. Set it to `terraform` only after the inventory and handoff are approved; no separate allow-list variable is required. Adoption identifiers are discovered by data sources at plan time. Do not commit or guess them.

### Shared maintenance edge

`maintenance/hosts.json` explicitly registers exact proxied web hostnames and
their status brand. It excludes status destinations, wildcard catch-alls and
DNS discovery/mail records. `terraform/maintenance.tf` deploys two stateless
Worker modes from `maintenance/worker.mjs`, gated to production. There is no
Worker storage, account subscription or zone-plan change.

The `maintenance_runtime` output is consumed by `platform-baremetal`, which
delivers it and a separate scoped runtime credential through the status workload
vault. `platform-workloads` provisions the credentials: connectivity can deploy
Worker code; the runtime can manage routes in approved zones and read DNS and
usage analytics, but cannot deploy code or change billing.

**Active maintenance routes are not Terraform resources.** The status controller
alone creates/removes exact-host routes after explicit operator confirmation.
Deploying connectivity must not clear or reset those operational routes.
Worker updates retain blocking responses even for an unrecognised hostname;
they never fall through to the origin. Restore active routes before retiring a
hostname from the registry.

To enrol another host, first configure an explicit proxied web DNS record, then
register its hostname/zone/brand. Extend runtime token zone scope when required.
Deploy workloads permissions, connectivity, and baremetal metadata in that order,
then reconcile the status application to load current secret mounts. Do not
enable proxying for unrelated DNS-only services as collateral work.

Worker tests use Node's built-in runner (`node --test maintenance/worker.test.mjs`);
Terraform tests cover production gating alongside the existing TLS safeguards.
The isolated `maintenance-check.bishopsbees.co.uk` custom domain has a tiny
Worker-owned normal response, not a production application origin. It is the only
canary registry exception to existing proxied DNS. Live lifecycle acceptance must
use this hostname rather than switching a user's website off.

### Backup mirroring

Setting `backup_to_azure: true` on a Cloudflare zone JSON additionally mirrors its records into a non-authoritative Azure DNS zone (a cold standby). Cutover is manual — repoint the registrar name servers to the Azure zone. Off by default.

### Subdomain delegation

`var.dns_delegations` delegates a subdomain from a Cloudflare parent zone to a new Azure DNS child zone: an `azurerm_dns_zone` child is created and `NS` records are added to the Cloudflare parent pointing at the child's name servers. Empty by default (mechanism only; no delegations configured yet).
