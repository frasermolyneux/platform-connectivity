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
`cloudflare_bot_management` controls. `xtremeidiots.com` uses Pro Super Bot
Fight Mode zone-wide: challenge definitely automated traffic with a managed
challenge and allow verified bots. The configuration disables legacy Bot Fight
Mode and retains the current likely-automated, static-resource, and WordPress
SBFM settings. These controls cover the whole zone, not only `www`, and may
challenge API clients and monitoring traffic. Super Bot Fight Mode supports
WAF custom-rule exceptions; this configuration adds none. The resource reads
existing AI-bot migration and managed `robots.txt` preferences to preserve them
instead of applying the provider's false defaults. Deployment credentials need
Bot Management Read and Write permissions. To roll back, configure the desired
SBFM actions explicitly; removing the declaration only stops Terraform
management and does not reset live settings.

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

`maintenance/hosts.json` registers exact proxied web hostnames and their status
brand. `terraform/maintenance.tf` deploys stateless Worker modes in Production.
The `maintenance_runtime` output is consumed by `platform-baremetal`; the
runtime controller owns active Worker routes. Connectivity must not create,
clear or reset those routes. Restore routes before retiring a hostname from the
registry. Do not proxy unrelated DNS-only services to enrol a host.

Worker tests use Node's built-in runner:
`node --test maintenance/worker.test.mjs`.

## Other DNS capabilities

`backup_to_azure` mirrors Cloudflare records into a non-authoritative Azure DNS
zone for manually operated failover. `var.dns_delegations` creates an Azure
child zone and delegates it from a Cloudflare parent. Both are opt-in through
the zone configuration or Terraform variables.
