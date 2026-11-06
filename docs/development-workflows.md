# Development Workflows

## GitHub Actions workflows
- **build-and-test**: Runs `terraform plan` for dev on feature/bugfix/hotfix branch pushes.
- **pr-verify**: Validates PRs with a dev plan; apply with `deploy-dev` label; prd plan with `run-prd-plan` label.
- **deploy-dev**: Manual dispatch to run `terraform plan` and `apply` against dev.
- **deploy-prd**: Triggered on push to main, weekly schedule (Thu 03:00 UTC), or manual dispatch. Applies dev first, then prd.
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

Branch/PR plan jobs use the shared pinned setup, read-only provider initialization,
validation and an unsaved redacted full plan. They never upload a binary plan:
even a harmless displayed plan can contain the Cloudflare token or sensitive
existing state. Apply jobs retain their existing same-job plan/apply path.

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
3. Merge; `deploy-prd` creates the zone, DNSSEC, settings, WAF, and records.
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
6. Merge; `deploy-prd` performs the import and reconciles.

Import blocks are idempotent — once an object is in state they are skipped, so
they stay in place and coexist with day-2 record additions and removals. Never
run `terraform import` or mutate production state from a local shell.

### Staged xtremeidiots.com handoff

The zone is declared for adoption but remains external until its protected
key is approved and enabled. The snapshot includes all 48 editable settings
returned by the zone inventory, including Full SSL mode, security level,
HTTPS rewrites, TLS 1.3 mode, hotlink protection, image optimization and
browser cache TTL. Non-editable settings remain unmanaged. Read-only discovery
fails closed if a selected setting is missing, no longer editable or differs
from the snapshot; review the production plan for provider support and no
setting updates. DNSSEC remains disabled. The custom-firewall
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
The existing managed WAF, apex rate limits, apex redirect, and legacy Page
Rules are staged for adoption with their current actions, order, thresholds,
and overrides. Discovery verifies the complete reviewed phase and Page Rule
snapshots, resolves IDs without committing them, and fails if live behavior
differs. The pipeline token needs zone-scoped Page Rules Write for the Page
Rule imports; grant it through `platform-workloads` before activation. The
status-edge configuration phase and workload-owned DNS stay with their
existing owners. The guarded snapshots are not a mechanism for deploying
new rules: later protection changes require a separate reviewed ownership and
rollout design, with client and traffic validation and rollback.

The pinned Cloudflare provider does not expose a managed ruleset execution
version. Discovery requires the live value `latest`, and the imported plan
must show no changes before applying; do not assume the provider can preserve
an arbitrary pinned version.

#### Optional plan-only rehearsal for PR #71

The `xtremeidiots-adoption-plan` job is a one-off rehearsal, not activation.
It runs only on a `rehearse-xtremeidiots-adoption` label-add event by
`frasermolyneux` on non-draft PR #71, from the same repository and
`frasermolyneux-cloudflare-zone-adoption` branch into `main`. It checks out
the exact event head, checks both the event and live PR against that checkout,
requires the live base to match the event and be an ancestor of that head, and
requires an exact PR comment by `frasermolyneux`:

```text
/approve-xtremeidiots-adoption-plan <40-character-head-commit-sha>
```

The comment must contain only that command and the full lowercase SHA.
Review the entire exact commit, including workflow, scripts, Terraform, and
external data sources, before providing the comment or adding the label.
Adding the label is the explicit request to run; an existing label, a push,
or an ordinary `run-prd-plan` event does not request this job. A new head
requires a new approval and a new label-add event. Removing an approval or
label before the final guard check prevents the plan; approval is reusable
for the same commit, so remove the comment when no longer intended.
The label must exist before it can be added; creating it and running this job
require separate authorization. PR comment/label write access is needed for
the designated account. Do not treat this guard as a security boundary against
an unreviewed PR author: PR workflow and Terraform code execute with the job's
credentials and could alter or bypass it. Production has no required
environment reviewers; restrict write, label, and production-secret access.

The job reads the existing Production `CLOUDFLARE_ADOPTED_ZONE_KEYS`, rejects
missing or malformed values, and adds only `xtremeidiots.com` to an in-process
set passed to this single full `terraform plan` using `-var`. It does not update
the protected variable, upload a plan, run apply, or write imports to state.
The regular production plan and deployment workflows do not receive the
override, including scheduled applies. The job still uses Production's
Cloudflare secret, Azure OIDC identity and real state backend; the Cloudflare
token's effective access, including Page Rules, must work. Planning obtains a
production state lock and may modify backend lock metadata; it can contend
with deployments and failed/cancelled runs may require lock recovery. Plan
and discovery output can reveal sensitive state or identifiers despite
redaction: restrict Actions log access and do not publish raw logs. No saved
binary plan is available to apply later.

Refresh inventory and establish ownership before any rehearsal. Stop on
unexpected changes, failed authorization, insufficient token access, or
drift. This preview does not authorize or ensure safety of a later import:
production activation and any apply require separate approval and a fresh
reviewed plan. Setting the persistent key early can allow a scheduled deploy
to apply the adoption without that review.

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
