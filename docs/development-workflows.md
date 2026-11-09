# Development Workflows

## GitHub Actions workflows
- **build-and-test**: Runs a dev plan and tests on feature/bugfix/hotfix branch pushes that change Terraform, maintenance, or this workflow.
- **pr-verify**: Plans dev for ready PRs; the `deploy-dev` label opts eligible PRs into dev apply instead, and `run-prd-plan` opts into a prd plan. The `verify-private-plans` label opts trusted same-repository PRs into no-change plan and private-upload verification for both environments.
- **deploy-dev**: Manual dispatch to run `terraform plan` and `apply` against dev.
- **deploy-prd**: Triggered on matching pushes to main, weekly schedule, or manual dispatch. Non-scheduled runs apply dev first, then prd; scheduled runs apply prd only.
- **deploy-strict-origin-tls**: Manual, scope-guarded production path for the one `redirect.xtremeidiots.net` strict TLS addition or its exact removal. Coordinate with ordinary deployments before use.
- **codequality**: Runs secure scanning on main pushes, ready PRs and on a schedule, plus dependency review on ready PRs.
- **destroy-environment**: Manual dispatch with environment choice (dev/prd).

## Local validation

Run formatting and validation locally without applying infrastructure:

```bash
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform init -backend=false -lockfile=readonly
terraform -chdir=terraform validate
python -m unittest discover -s terraform/scripts -p 'test_*.py'
terraform -chdir=terraform test
```

Select the exact Terraform version from `terraform/.terraform-version` first.
The custom-firewall preservation test uses the installed provider against a local
fake API and isolated temporary state; it does not contact Cloudflare.

Backend-aware plans require access to the Azure state backend and the environment's Azure and Cloudflare credentials. Use the supported GitHub Actions workflows for authoritative plans and all applies. Never run `terraform apply` from a local machine.

Default branch/PR plan jobs use read-only provider initialization, validation and
an unsaved plan. The opt-in `verify-private-plans` jobs run on labeling and on
subsequent opened, synchronized, reopened, or ready-for-review events while the
label remains. They fail on changes or errors; successful no-change plans are
uploaded without applying. They are restricted to same-repository PRs authored by
an owner, member, or collaborator and do not run with the `deploy-dev` label.

The opt-in jobs and shared plan/apply action upload a source- and toolchain-bound
bundle containing the binary plan, metadata and provider lock via OIDC to the
pre-existing private `tfplan` container in the initialized backend account. A
bundle can contain credentials or sensitive state, even when the displayed plan
has no changes. Restrict blob access and manage retention separately; the action
does not create the container or configure its access or retention.

## Guarded strict TLS recovery

The manual `deploy-strict-origin-tls` workflow retains a narrow path to add or
remove the exact `redirect.xtremeidiots.net` rule. Its
[plan guard](../terraform/scripts/guard_strict_tls_plan.py) requires a complete,
drift-free, in-place change between an empty entrypoint and that single rule,
with no unrelated changes. Explicit rule logging is rejected; stop for separate
review if the live rule contains it. The workflow checks the current `main` SHA
and a binding to the reviewed Terraform source, then applies the same
scope-validated saved plan. A source change can invalidate that binding.

For rollback, obtain separate authorization and a reviewed procedure before
changing the `.net` `origin_tls_hostnames` list to `[]`. A matching main push
can apply the change through ordinary `deploy-prd` without the guard, so control
ordinary, scheduled, manual, queued and out-of-band production runs before
merging. Do not assume merging a revert and then dispatching the guard is safe.
Production jobs share a concurrency group, but it does not prevent out-of-band
writes; a newer pending job can cancel an older pending job. Check actual job
outcomes.

The guard cannot establish certificate health, Cloudflare's effective logging
default or live traffic behavior, nor prevent out-of-band changes after refresh.
For an addition, verify the origin certificate and renewal readiness separately.
After either operation, verify the live rule and HTTP/HTTPS behavior; a fake-API
test is not evidence of a live apply. [Full (strict)](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/full-strict/)
does not force HTTP visitors to use HTTPS. Keep saved plans and their JSON out of
public artifacts and logs.

## Cloudflare zones: new domains vs adopting existing ones

Cloudflare zones default to external ownership (record-only). Setting a zone's
`management` to `terraform` in its JSON definition brings the zone, DNSSEC, settings, WAF
ruleset, and records under Terraform management. There are two paths.

### New domain (does not yet exist in Cloudflare) — no import

Terraform creates everything from scratch. There is nothing to import.

1. Create `terraform/zones/<domain>.json` with `dns_provider: cloudflare`,
   `management: terraform`, the intended `plan_profile`, `records`, and flags.
2. Ensure the Production `CLOUDFLARE_ACCOUNT_ID` variable and `CLOUDFLARE_API_KEY`
   secret provisioned by `platform-workloads` provide the intended account and
   permissions. Review a production plan before deployment.
3. Merge and deploy through the ordinary production path; that path creates the
   zone, settings, records, and any enabled DNSSEC and WAF resources.
4. Point the registrar's nameservers at the Cloudflare-assigned NS.

### Existing domain (already in Cloudflare) — adopt via data-source import

The zone already exists, so it and its configured DNSSEC, settings, and enabled
custom-firewall ruleset are imported into state rather than recreated. No
identifiers are committed and no bespoke workflow is involved —
`cloudflare_imports.tf` reads the live zone via the `cloudflare_zone`,
`cloudflare_dns_records`, and `cloudflare_rulesets` data sources and the `import`
blocks bind each object by its discovered ID.

1. Prepare `terraform/zones/<domain>.json` with `adopt_existing: true` and the
   correct `plan_profile`. Keep `management: external` and the existing `zone_id`
   until the handoff is approved: configured records remain managed without
   adopting the zone or its zone-wide controls.
2. Declare the desired records in `records[]`:
   - An empty or newly created zone with no live records needs nothing here —
     add whatever records you want Terraform to create.
   - When adopting a zone that already has live records, list them in `records[]`
     as desired state. Any listed record that also exists live is imported (bound
     by the ID the `cloudflare_dns_records` data source discovers); any not yet
     live is created. Live records you omit stay unmanaged.
3. If the zone already has a custom-firewall ruleset, reconcile its rules into
   a reviewed `waf_custom_ruleset` snapshot and set
   `waf_preserve_existing: true` before proceeding — the ruleset resource owns
   the whole `http_request_firewall_custom` phase, so an incomplete rule list
   would replace the live rules on apply. Adopted zones fail closed if that
   entrypoint is missing, ambiguous, unreadable, or differs from the snapshot.
   New zones may create the shared default ruleset.
4. Once approved, set `management: terraform` in the zone JSON. This declaration
   alone selects zone-wide management; `adopt_existing: true` selects discovery
   and import rather than creation. Ensure the Production `CLOUDFLARE_ACCOUNT_ID`
   variable and `CLOUDFLARE_API_KEY` secret provisioned by `platform-workloads`
   provide the intended account and permissions.
5. Run the production plan through **PR Verify** with the `run-prd-plan` label.
   Review it for any unexpected create/replace/delete on imported objects and any
   intended settings hardening before approval.
6. Merge and deploy through the ordinary production path; that path performs the
   import and reconciliation.

Import blocks are idempotent — once an object is in state they are skipped, so
they stay in place and coexist with day-2 record additions and removals. A
configured Page Rule or phase ruleset is created when no match exists, imported
when exactly one match exists, and rejected on ambiguity or API errors. A
same-target Page Rule that differs from its reviewed configuration fails rather
than being silently duplicated.

Every Terraform-managed Cloudflare DNS record needs a stable, non-empty `key`
unique within its zone and type. Keys form Terraform resource addresses and must
not encode mutable content. For a record already in state under the legacy
content-derived address, obtain the exact old address from that environment's
read-only `terraform state list`, add a static `moved` block, and verify a plan
shows a state-only move with no DNS create, update, or destroy. Never run
`terraform state mv`, `terraform import`, or mutate production state from a
local shell. Unsupported DNS record types fail closed; add resource and live
record matching support before declaring them.

For adopted zones, set `settings_preserve_existing: true` and include an
explicit snapshot in `settings`; plan-profile defaults are not inherited.
The adoption plan reads each configured live setting and each existing configured
ruleset, rejecting missing or mismatched values, extra or reordered rules, and
provider read errors before import. A configured managed-ruleset version of
`latest` is matched to Cloudflare's provider-resolved active version. Keep
`adopt_existing: true` through the
import deployment. After imports are present in state, set it to `false` in a
follow-up change to leave adoption-only snapshot checks and continue ordinary
day-2 configuration changes. Keep `settings_preserve_existing: true` to retain
the explicit managed settings subset without inheriting profile defaults;
change that flag only when intentionally adopting the profile's full setting
set.

### Staged xtremeidiots.com handoff

The zone is declared for preservation-first adoption. Its settings snapshot
includes every zone setting the Cloudflare API marked editable, preserving the
live Pro values and disabled DNSSEC. The custom-firewall snapshot retains both
hotlink exceptions and the AI Crawl Control rule in their existing order,
including their actions and response. Its `waf_preserve_existing` guard reads
the whole entrypoint and fails if it is missing or differs from the snapshot;
discovered default rule references are not committed. The rule name must remain
`default`: changing it forces a replacement with the pinned provider.

The `rulesets` map also snapshots the active managed-WAF, rate-limit and
dynamic-redirect entrypoints. Only the zone's active entrypoints are modeled;
managed-ruleset catalog entries are not deployed protections. `page_rules`
captures the two active legacy Page Rules with their targets, priorities,
actions and status. Import discovery adopts one exact match, creates a missing
rule, and fails closed on ambiguity, a same-target mismatch, or API errors.
These declarations are for adoption
without changing live behavior; they do not retire or harden any rule.
AI Crawl Control can change the same custom-firewall phase Terraform would own.
Before activation, coordinate a single owner and freeze or reconcile dashboard
edits; do not rely on Terraform and AI Crawl Control independently editing the
phase. Re-inventory before the production plan and stop on any mismatch. Review
the plan for import-only changes and no zone setting, DNS, DNSSEC, ruleset
replacement, rule, or other behavior changes, and for no duplicate imports of
already-managed DNS records. The status-edge-owned `http_config_settings`
phase, active maintenance routes, and platform-notifications-owned ACS/SPF
records remain untouched. The guarded snapshots are not a mechanism for
deploying new firewall rules or retiring Page Rules: those changes require a
separate reviewed ownership and rollout design, with client and traffic
validation and rollback.

## Conventions

### Retiring the legacy Talk apex redirect

`legacy_apex_redirect_disabled` opts the external Talk zone into adoption of its
existing HTTPS apex-to-www Page Rule. Normal full plans discover its identifier
with a read-only Cloudflare lookup, then the import block adopts it and changes
only `status` to `disabled`. Its target, destination, status code and priority
must match the reviewed contract; missing, duplicate, truncated or changed rules
fail closed. No identifiers or credentials are committed. Discovery receives
the existing `TF_VAR_cloudflare_api_token` through the process environment, never
the external data query or state. The provider cannot list legacy Page Rules,
so the pinned external provider supplies this read-only lookup.

The scoped `Page Rules Write` grant for `talkwithtiles.com` is owned by
`platform-workloads`. When initially adopting the rule, review a full Production
plan showing exactly one import and one status update, with no create/delete or
unrelated rule changes. The retained disabled rule is protected against
destruction; it does not transfer ownership of the zone or any other forwarding
rule.

### ACS apex TXT ownership handoff

The `removed` block in `terraform/dns_records.tf` relinquishes the isolated
`molyneux.io/@` TXT set without destroying it for ownership by
`platform-notifications`. If it still appears in this state, review the production
plan to ensure it is only forgotten, with no live record changes, then deploy
through the production workflow. Confirm the old binding is absent from this
state before the receiving repository imports it. Preserve its SPF and do not
delete the live record set, use local state commands, or disturb unrelated DNS
records.

- DNS zones are configuration-driven via JSON files in `terraform/zones/`. To add a new domain, create a JSON file following the existing schema.
- An explicit empty `origin_tls_hostnames` list clears retired hostname rules while retaining the protected, stack-owned configuration entrypoint. Omit the property only for zones this stack has never owned. The `xtremeidiots.com` configuration phase is already owned by the status edge stack; its exact-host maps rule must be maintained there, not by creating a competing entrypoint.
- `redirect.xtremeidiots.net` uses an exact-host strict origin TLS override without changing the zone-wide SSL setting. See [guarded strict TLS recovery](#guarded-strict-tls-recovery) before changing it.
- Cloudflare zones default to external ownership. Set `management` to `terraform` only when the zone and its controls will be adopted into this state.
- Terraform-managed Cloudflare zones support `free` and `pro` setting profiles, optional `settings` overrides, `dnssec_enabled`, `waf_custom_rules_enabled`, phase-keyed `rulesets`, and named `page_rules`.
- Private link zones are listed in `terraform/private_link_zones/prd.json`.
- Production-only resources are gated by tfvars: dev has no `dns_zones_path` set, prd points to the zone configurations.
- Tags are applied from tfvars; keep `Git` pointing at the repo URL for traceability.
