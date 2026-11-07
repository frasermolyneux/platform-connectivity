# Development Workflows

## GitHub Actions workflows
- **build-and-test**: Runs `terraform plan` for dev on feature/bugfix/hotfix branch pushes.
- **pr-verify**: Validates PRs with a dev plan; apply with `deploy-dev` label; prd plan with `run-prd-plan` label. The `verify-private-plans` label opts trusted same-repository PRs into no-change plan and private-upload verification for both environments.
- **deploy-dev**: Manual dispatch to run `terraform plan` and `apply` against dev.
- **deploy-prd**: Triggered on push to main, weekly schedule, or manual dispatch. Ordinary production deploys apply a saved plan only when the guarded `.net` TLS ruleset is unchanged; non-scheduled runs still apply dev.
- **deploy-strict-origin-tls**: Manual, scope-guarded production path for the one `redirect.xtremeidiots.net` strict TLS addition. It is fail-closed pending the prerequisites below.
- **codequality**: Scheduled Monday 3am UTC. Runs DevOps secure scanning and dependency review on PRs.
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
does not create the container or configure its access or retention. During the
guarded strict TLS rollout, the temporary ordinary production job uses a private
runner-local plan instead of the shared action and does not upload that bundle
or publish its apply receipt.

## Guarded strict TLS rollout

The ordinary `deploy-prd` production job remains available for unrelated changes.
It validates and applies the same saved plan, rejecting any change, drift, import,
move, or unknown value in the `xtremeidiots.net` origin TLS ruleset. It also
rejects an absent target and deferred changes. It runs only on current `main`,
including for manual dispatch. If the TLS addition is pending, an ordinary plan
that also contains unrelated changes is rejected in its entirety; first resolve
the exact TLS addition through its dedicated guarded workflow. Removing this
temporary restriction and restoring the shared production action requires review.
As before, non-scheduled production runs require the dev job to succeed. A
queued run whose commit is no longer current `main` fails rather than applying
stale configuration.
The manually dispatched destroy workflow is separate and is not authorized by
this procedure. Do not merge or deploy #73 until all authorization conditions
have been demonstrated.

This change cannot disable historical workflow revisions. Existing branches,
queued jobs, and reruns of older `main` runs may still invoke the old unguarded
production apply. The current Production environment has no protection rules
or branch policy. [Disabling the legacy workflow in GitHub][disable-workflow]
prevents new triggers and reruns while it stays disabled, but does not cancel
existing runs and can be reversed by an authorized user; it is an operational
stop, not an in-repository enforcement mechanism. Before rollout, inspect
queued and active production jobs, and coordinate against starting historical
workflow revisions or reruns. This is a residual operational risk: a historical
run can still bypass both guards. A branch restriction alone does not block
reruns of old `main` commits. The ordinary, guarded and destroy jobs share the
production concurrency group, but historical or other workflows and direct
access must be assessed separately; concurrency does not stop out-of-band writes.
GitHub's default concurrency queue allows only one pending job; a newer
production-group job, including a PR plan, can cancel a pending deployment.
Check job outcomes rather than assuming a queued deployment will run.

[disable-workflow]: https://docs.github.com/en/actions/how-tos/manage-workflow-runs/disable-and-enable-workflows

The guarded workflow can run only on the current `main` commit, after the
workflow and target change have passed normal PR review and checks. Before
rollout, independently verify the origin certificate and renewal readiness.
The Production environment does not currently require a human reviewer; this
workflow's authorization is for the exact machine-validated scope below, not
for an arbitrary production plan.

The plan must be a complete, drift-free in-place update of the existing
`xtremeidiots.net` configuration ruleset from no rules to exactly the specified
host, action, and strict TLS setting. Imports, moves, replacements, deletions,
other resource or output changes, deferred changes, and unknown non-metadata
values are rejected, except the provider-computed unknown `logging` on the new
rule alone. Its planned logging must be absent or null; no explicit logging
setting, including `false`, is accepted. The workflow binds the ruleset source
file to the reviewed Git blob that omits logging, before planning and applying.
Changes to that file require reviewing and updating this binding.

The pinned Cloudflare provider schema accepts an explicit
`logging = { enabled = false }`, which produces a known value in a synthetic
local plan. Cloudflare's [API schema][cloudflare-api-schema] defines
`rulesets_SetConfigRule` in terms of `rulesets_Rule`, which includes an optional
`logging` object; its `enabled` field controls whether a rule match generates a
log. The schema does not define the value when logging is omitted. Explicit
false is an additional behavior choice, not proof of the omitted default.
An isolated test with the pinned provider and synthetic state captures its
in-place update dry-run request to a fake local API and verifies the new rule
omits logging. This is the same omission used by the status-web rules; it does
not prove Cloudflare's effective default or its behavior at apply time. Verify
the exact saved plan, live rule after deployment, and HTTP behavior; an absent
logging field in the API response does not establish whether logging occurs.
The workflow does not itself verify the live result after applying.

[cloudflare-api-schema]: https://github.com/cloudflare/api-schemas/blob/main/openapi.json

Cloudflare documents that [Full (strict)][strict-mode] follows [Full mode][full-mode]
with additional origin certificate validation: plain HTTP visitor requests use
plain HTTP to the origin, while HTTPS requests use HTTPS. It is not the
`origin_pull` SSL-only mode. Verify the actual HTTP and HTTPS behavior after an
authorized deployment; this plan guard cannot establish live traffic behavior.

[strict-mode]: https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/full-strict/
[full-mode]: https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/full/

The workflow creates a saved plan in the runner's private temporary directory,
validates its JSON, checks its SHA-256, and applies that same binary file in the
same job. It checks that main has not advanced before planning or applying.
Terraform's own state serial check still applies. These checks cannot prevent
out-of-band changes between refresh and apply or establish certificate health;
operators must control that window and verify the origin separately. Never put
the binary plan or its JSON representation in public artifacts or logs.

## Cloudflare zones: new domains vs adopting existing ones

Cloudflare zones default to external ownership (record-only). Setting a zone's
`management` to `terraform` and adding its key to the protected
`CLOUDFLARE_ADOPTED_ZONE_KEYS` variable brings the zone, DNSSEC, settings, WAF
ruleset, and records under Terraform management. There are two paths.

### New domain (does not yet exist in Cloudflare) — no import

Terraform creates everything from scratch. There is nothing to import.

1. Create `terraform/zones/<domain>.json` with `dns_provider: cloudflare`,
   `management: terraform`, the intended `plan_profile`, `records`, and flags.
2. Add the zone key to the Production `CLOUDFLARE_ADOPTED_ZONE_KEYS` variable.
3. Merge and deploy through the ordinary production path; that path creates the
   zone, DNSSEC, settings, WAF, and records, provided the TLS guard passes.
4. Point the registrar's nameservers at the Cloudflare-assigned NS.

### Existing domain (already in Cloudflare) — adopt via data-source import

The zone already exists, so it (and its DNSSEC, settings, and any existing
custom-firewall ruleset) is imported into state rather than recreated. No
identifiers are committed and no bespoke workflow is involved —
`cloudflare_imports.tf` reads the live zone via the `cloudflare_zone`,
`cloudflare_dns_records`, and `cloudflare_rulesets` data sources and the `import`
blocks bind each object by its discovered ID.

1. Ensure `terraform/zones/<domain>.json` has `management: terraform`,
   `adopt_existing: true`, and the correct `plan_profile`. Retain the existing
   `zone_id` while the protected adoption key is absent: the zone and its
   records stay externally managed until activation, and a missing ID fails
   planning instead of dropping those records.
2. Declare the desired records in `records[]`:
   - An empty or newly created zone with no live records needs nothing here —
     add whatever records you want Terraform to create.
   - When adopting a zone that already has live records, list them in `records[]`
     as desired state. Any listed record that also exists live is imported (bound
     by the ID the `cloudflare_dns_records` data source discovers); any not yet
     live is created. Live records you omit stay unmanaged.
3. If the zone already has a custom-firewall ruleset, reconcile its rules into
   a reviewed `waf_custom_ruleset` snapshot before proceeding — the ruleset resource owns the whole
   `http_request_firewall_custom` phase, so an incomplete rule list would replace
   the live rules on apply. New-ish domains usually have no such ruleset and it
   is created fresh (a plan-time precondition fails loudly if more than one
   entrypoint ruleset exists).
4. Activate the zone by adding its key to the `cloudflare_adopted_zone_keys` list
   in this workload's definition in `platform-workloads`
   (`terraform/workloads/platform/platform-connectivity.json`, Production
   environment) and applying `platform-workloads`. That provisions the protected
   `CLOUDFLARE_ADOPTED_ZONE_KEYS` and `CLOUDFLARE_ACCOUNT_ID` Production variables
   (and the `CLOUDFLARE_API_KEY` secret) — they are source-controlled, not set by
   hand. Until a zone key is listed there, adoption stays fail-closed.
5. Run the production plan through **PR Verify** with the `run-prd-plan` label.
   Review it for any unexpected create/replace/delete on imported objects and any
   intended settings hardening before approval.
6. Merge and deploy through the ordinary production path; that path performs the
   import and reconciliation, provided the TLS guard passes.

Import blocks are idempotent — once an object is in state they are skipped, so
they stay in place and coexist with day-2 record additions and removals. Never
run `terraform import` or mutate production state from a local shell.

### Staged xtremeidiots.com handoff

The zone is declared for adoption but remains external until its protected
key is approved and enabled. Its settings preserve the live Full SSL mode,
disabled DNSSEC, security level, HTTPS rewrites, TLS 1.3 mode, hotlink
protection, image optimization and browser cache TTL. The custom-firewall
snapshot retains both hotlink exceptions and the AI Crawl Control rule in
their existing order, including their actions and response. Its
`waf_preserve_existing` guard reads the whole entrypoint and fails if it is
missing or differs from the snapshot; discovered default rule references are
not committed. The rule name must remain `default`: changing it forces a
replacement with the pinned provider.

AI Crawl Control can change the same custom-firewall phase Terraform would own.
Before activation, coordinate a single owner and freeze or reconcile dashboard
edits; do not rely on Terraform and AI Crawl Control independently editing the
phase. Re-inventory before the production plan and stop on any mismatch. Review
the plan for no zone setting, DNS, DNSSEC, ruleset replacement, rule, or other
behavior changes, and for no duplicate imports of already-managed DNS records.
The existing managed WAF, apex rate limits, apex redirect, legacy Page Rules,
status-edge configuration phase and workload-owned DNS remain untouched.
The guarded snapshot is not a mechanism for deploying new firewall rules:
later protection changes require a separate reviewed ownership and rollout
design, with client and traffic validation and rollback.

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
`platform-workloads`. Review a full Production plan showing exactly one import
and one status update, with no create/delete or unrelated rule changes, before
merging. The retained disabled rule is protected against destruction; it does
not transfer ownership of the zone or any other forwarding rule.

### ACS apex TXT ownership handoff

The existing `molyneux.io/@` TXT set remains live throughout transfer to
`platform-notifications`. The first revision isolated it at
`azurerm_dns_txt_record.notification_apex[0]` using a declarative move, deployed
with zero Azure record changes or deletions. This separate release removes its
configuration with a `removed` block and `destroy = false`, removing only the
corresponding apex JSON entry. Its production plan must forget exactly that
isolated set and show zero create, update or delete operations. Apply the release
before the receiving repository imports `/TXT/@` and preserves its existing SPF.
Never delete the live record set, use local state commands, or remove unrelated
TXT, SPF, MX, DKIM or DMARC records during the handoff.

- DNS zones are configuration-driven via JSON files in `terraform/zones/`. To add a new domain, create a JSON file following the existing schema.
- An explicit empty `origin_tls_hostnames` list clears retired hostname rules while retaining the protected, stack-owned configuration entrypoint. Omit the property only for zones this stack has never owned. The `xtremeidiots.com` configuration phase is already owned by the status edge stack; its exact-host maps rule must be maintained there, not by creating a competing entrypoint.
- Cloudflare zones default to external ownership. Set `management` to `terraform` only when the zone and its controls will be adopted into this state.
- Terraform-managed Cloudflare zones support `free` and `pro` setting profiles, optional `settings` overrides, `dnssec_enabled`, and `waf_custom_rules_enabled`.
- Private link zones are listed in `terraform/private_link_zones/prd.json`.
- Production-only resources are gated by tfvars: dev has no `dns_zones_path` set, prd points to the zone configurations.
- Tags are applied from tfvars; keep `Git` pointing at the repo URL for traceability.
