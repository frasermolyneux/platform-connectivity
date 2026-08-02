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
terraform -chdir=terraform validate
```

Backend-aware plans require access to the Azure state backend and the environment's Azure and Cloudflare credentials. Use the supported GitHub Actions workflows for authoritative plans and all applies. Never run `terraform apply` from a local machine.

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
   `adopt_existing: true`, and the correct `plan_profile`.
2. Declare the desired records in `records[]`:
   - An empty or newly created zone with no live records needs nothing here —
     add whatever records you want Terraform to create.
   - When adopting a zone that already has live records, list them in `records[]`
     as desired state. Any listed record that also exists live is imported (bound
     by the ID the `cloudflare_dns_records` data source discovers); any not yet
     live is created. Live records you omit stay unmanaged.
3. If the zone already has a custom-firewall ruleset, reconcile its rules into
   `cloudflare_waf.tf` before proceeding — the ruleset resource owns the whole
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

## Conventions
- DNS zones are configuration-driven via JSON files in `terraform/zones/`. To add a new domain, create a JSON file following the existing schema.
- Cloudflare zones default to external ownership. Set `management` to `terraform` only when the zone and its controls will be adopted into this state.
- Terraform-managed Cloudflare zones support `free` and `pro` setting profiles, optional `settings` overrides, `dnssec_enabled`, and `waf_custom_rules_enabled`.
- Private link zones are listed in `terraform/private_link_zones/prd.json`.
- Production-only resources are gated by tfvars: dev has no `dns_zones_path` set, prd points to the zone configurations.
- Tags are applied from tfvars; keep `Git` pointing at the repo URL for traceability.
