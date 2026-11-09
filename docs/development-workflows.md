# Development Workflows

## Validate locally

Select the Terraform version in `terraform/.terraform-version`, then run:

```bash
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform init -backend=false -lockfile=readonly
terraform -chdir=terraform validate
python -m unittest discover -s terraform/scripts -p 'test_*.py'
terraform -chdir=terraform test
node --test maintenance/worker.test.mjs
git diff --check
```

The Cloudflare preservation and ownership-release tests use isolated synthetic
data; they do not call Cloudflare or change Terraform state. Backend-aware plans
use the normal environment workflows and locking. Never run local `terraform
apply`, imperative import, or state mutation.

## Plans and deployments

Pull requests receive the configured development validation and plan.
Production plans are opt-in through the repository's `run-prd-plan` label.
Applies use the repository deployment workflows; a local plan does not
authorize or replace a deployment review.

The optional `verify-private-plans` workflow uploads a bundle that can contain
credentials or sensitive state, even if the displayed plan appears harmless.
Keep that bundle private and handle it according to the storage access and
retention controls for the backend.

Before deploying Cloudflare changes, inspect the complete environment plan.
For preservation or ownership changes, confirm imports and address moves are
state-only, and stop on unintended creates, updates, destroys, drift or
ambiguous ownership. Configuration and existing service owners are described
in [`architecture-overview.md`](architecture-overview.md) and represented in
`terraform/zones/*.json`.

## Guarded strict origin TLS

The manual `deploy-strict-origin-tls` workflow is restricted to the exact
`redirect.xtremeidiots.net` rule. Its
[plan guard](../terraform/scripts/guard_strict_tls_plan.py) accepts only a
complete, drift-free in-place addition or removal of that rule with no
unrelated changes. The workflow binds execution to the reviewed source and
applies the same saved plan it validates.

For adopted zones, the guard obtains the expected zone ID from the named
managed-zone value in the saved plan and cross-checks the independent live
zone discovery. It does not depend on a committed zone ID. Tests cover the CLI
entrypoint, discovery mismatch/ambiguity and both source bindings.

The guard cannot establish certificate health or live traffic behavior, nor
prevent out-of-band changes after refresh. Verify certificate readiness before
an addition and verify the live rule and HTTP/HTTPS behavior after deployment.
Coordinate with ordinary and scheduled Production deployments; the workflow's
concurrency group does not prevent out-of-band writes.

## Cloudflare configuration

`terraform/zones/*.json` is the configuration entry point.
`terraform/cloudflare_imports.tf` implements data-source-driven discovery;
related Terraform resources and scripts validate settings, DNS, rulesets and
Page Rules. Follow those definitions when changing supported controls. Keep
resource addresses stable; use declarative `moved` blocks for address changes
and verify the plan before deployment.

Keep workload- or controller-owned DNS, rulesets and Worker routes with their
current owners. Do not add a second Terraform binding for a resource already
managed elsewhere. When ownership is ambiguous or a snapshot no longer matches
Cloudflare, stop and reconcile with the owner rather than masking drift.
