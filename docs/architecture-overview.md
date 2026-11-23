# Architecture Overview

This repository uses Terraform to manage shared tenant DNS connectivity.

- Public DNS configuration is in `terraform/zones/`; Private Link zones are in
  `terraform/private_link_zones/`.
- Environment behavior is selected by `terraform/tfvars/`. Dev creates only its
  DNS resource group; Production enables public DNS and
  maintenance Workers.
- Private Link DNS is optional. Add zone names to the environment's
  `private_link_zones_file` JSON list when required; an empty list provisions
  no private zones. Production currently configures an empty list.
- Root Terraform configuration and the published output contract are in
  `terraform/*.tf` and `terraform/outputs.tf`.
- `platform-workloads` remote state supplies workload resource-group metadata.

## DNS providers and ownership

Zone JSON declares Azure or Cloudflare DNS. Azure zones use grouped record
collections; Cloudflare zones use `records[]`. The JSON files are the source of
truth for desired configuration; this document describes behavior, not a zone
inventory.

During migration an Azure zone may also declare a nested `cloudflare` object.
Both zone resources remain managed, while `dns_zones` continues to expose the
Azure zone until the migration is complete. Only explicitly listed Cloudflare
records are managed; workload-owned records remain with their owners. Adopt
existing zones and DNSSEC through `import_existing`, which resolves identifiers
at plan time without committing them.

Cloudflare zones default to `management: external`, which limits this stack to
the explicitly configured records and hostname origin TLS overrides. Setting
`management: terraform` declares zone-wide ownership. The zone JSON remains the
source for managed records, settings, DNSSEC, rulesets and Page Rules.

For existing zones, use an explicit `settings` snapshot with
`settings_preserve_existing: true`. This prevents plan-profile defaults from
silently expanding the settings owned by this stack. DNS record keys are stable
per type and independent of mutable content. Ruleset rules use explicit stable
`ref` values. Custom firewall rulesets own an entire phase, so keep their
configured rules complete and coordinated with the owning service.

Managed Cloudflare zone snapshots set the minimum edge TLS version to 1.2.
Newly imported zones that do not yet declare settings retain their existing
Cloudflare TLS minimum until their settings are reviewed.
Page Rules retain destruction protection. The retired tcadmin Page Rule has
a dedicated zero-instance resource and moved block to allow only its deletion;
review that deletion in the production plan.

`managed_waf_hostnames` declares exact proxied HTTP service hostnames and
enables the plan-appropriate managed WAF: the Free Managed Ruleset on Free
zones, or the broader Cloudflare Managed Ruleset on Pro zones. Unlisted
hostnames, DNS-only and non-HTTP services are excluded. Explicit
`http_request_firewall_managed` rulesets take precedence and must contain
their complete desired configuration. Cloudflare may already own a phase
entrypoint, including automatically deployed Free rules; reconcile its live
contents and ownership before declaring hostnames for any additional zone.
Do not treat an omitted hostname as proof that Cloudflare WAF is disabled.

For Terraform-managed zones, `bot_management` configures the supported
`cloudflare_bot_management` controls. `xtremeidiots.com` keeps this resource
managed with legacy Bot Fight Mode off and its Pro SBFM actions set to allow;
static-resource protection, JavaScript detections, and WordPress optimization
are off. This leaves bot challenges disabled across the whole zone. Keep the
resource configured when disabling bot protections: the pinned provider's
resource deletion removes it from Terraform state without resetting the live
Cloudflare settings. The resource reads existing AI-bot migration and managed
`robots.txt` preferences to preserve them instead of applying the provider's
false defaults. Deployment credentials need Bot Management Read and Write
permissions.

Keep one owner per Cloudflare resource. Workload-owned DNS, status-owned
`http_config_settings` entrypoints, Worker-generated DNS records and
runtime-managed Worker routes remain with their current stacks/controllers.
Do not declare them here. The exact ownership and desired state live in
Terraform configuration.

Supply Cloudflare credentials through the deployment environment, never zone
JSON or committed files. The `dns_zones` output shape is a cross-repository
contract; review `terraform/outputs.tf` before changing it.

## Hostname origin TLS

`origin_tls_hostnames` opts an external zone into an exact-host
`http_config_settings` rule without changing zone-wide SSL settings. Only
declared, proxied hostnames are accepted; wildcard, duplicate or unproxied
names fail validation. `origin_tls_preserve_existing` retains this stack's
existing owner identity when a zone becomes Terraform-managed. It does not
claim ownership of another stack's entrypoint. The owner identity and ruleset
have destruction protection. Use the narrow recovery path described in
[`development-workflows.md`](development-workflows.md) for the explicitly
guarded strict-TLS change.

## Maintenance Workers

`maintenance/ingress-catalog.json` is copied from `platform-workloads` commit
`18b6ae285b98149c31cbf64407ab049c45bda66f`. The maintenance registry derives
catalog hosts from `current.status`, resolving their existing status brand via
the canonical target, and merges the canary and non-catalog hosts in
`maintenance/hosts.json`. The explicit enrollment in `terraform/maintenance.tf`
adds only approved canonical hosts; current additions are the three canonical
TripSidekick and Talkwithtiles hosts plus IDP and Radar. Other target membership
does not activate maintenance. For enrolled hosts whose DNS records are owned
elsewhere, Terraform reads the exact Cloudflare record without claiming DNS
ownership and checks that it is proxied.
`maintenance/host-order.json` preserves the deployed registry order; new current
hosts append in hostname order.
Existing aliases remain in the current registry until their routes can be
restored and the controller configuration synchronized; target-only aliases
do not gain independent controls. `terraform/maintenance.tf` deploys stateless
Worker modes in Production.
The `maintenance_runtime` output is consumed by `platform-baremetal`; the
runtime controller owns active Worker routes. Connectivity must not create,
clear or reset those routes. Restore routes before retiring a hostname from the
registry. Baremetal materializes the output into the status workload's Key Vault;
changes to registry membership require that configuration and the mounted
controller metadata to be synchronized with the Workers. Deploy Workers first,
then apply the baremetal configuration and verify both status hosts have
reconciled the mounted secret before using new controls. Do not proxy unrelated
DNS-only services to enrol a host.

`maintenance_controller_excluded_aliases` defaults to empty and can explicitly
remove currently registered catalog aliases from controller metadata without
removing Worker support. This does not alter routes. Coordinate and verify both
controller mounts and restore any active alias routes before a later redirect
cutover or Worker removal; stale controllers can still operate until refreshed.
Non-catalog hosts are not eligible for this catalog-alias exclusion.

Worker tests use Node's built-in runner:
`node --test maintenance/worker.test.mjs`.
IDP and Radar maintenance bypass is limited to the exact callback/service
path-method pairs in `maintenance/worker.mjs`; `/signin-oidc` is POST-only.
There is no cookie/header blanket exemption. Login initiation and anonymous
collector discovery remain subject to maintenance.

For registered `idp.molyneux.io` and `radar.molyneux.io`, the Worker bypasses
maintenance only for the evidenced OAuth callback and service endpoint methods
listed in `maintenance/worker.mjs`. Radar's inventory events endpoint is
anonymous at the application routing layer but requires signature verification.
The Worker does not authenticate requests; origin authorization and webhook
verification remain authoritative. Other requests, including login and IDP's
anonymous collector discovery, remain subject to maintenance even when they
carry cookies or an Authorization header. These hostnames are not enrolled or
proxied by this policy alone.

TripSidekick's `.app` and `.net` zones, Talkwithtiles, BQBA and DM Electrical
use zone-owned Single Redirect rules for their public catalog aliases, retaining
path, query, and method.
Each zone's existing Always Use HTTPS setting handles HTTP. Their origin
redirects remain in place. The other catalog aliases retain their current
behavior until maintenance routes and controller metadata are coordinated.

## Other DNS capabilities

`backup_to_azure` mirrors Cloudflare records into a non-authoritative Azure DNS
zone for manually operated failover. `var.dns_delegations` creates an Azure
child zone and delegates it from a Cloudflare parent. Both are opt-in through
the zone configuration or Terraform variables.
