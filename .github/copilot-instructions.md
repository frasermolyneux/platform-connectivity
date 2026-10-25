# Copilot instructions

`platform-connectivity` is the Terraform source of truth for shared Azure and Cloudflare DNS connectivity in the Molyneux.IO tenant. Keep workload-owned records and application-specific controls in their owning repositories.

## Layout and contracts

- `terraform/*.tf` contains the root configuration; there are no child modules.
- `terraform/zones/*.json` defines public zones and records. Azure zones use grouped record collections; Cloudflare zones use `records[]` and explicit ownership settings.
- `terraform/private_link_zones/prd.json` lists production Private Link DNS zones.
- `terraform/tfvars/{dev,prd}.tfvars` selects environment behavior; matching backend files are under `terraform/backends/`.
- Dev intentionally creates only the DNS resource group. Prd enables public DNS and Private Link zones.
- `terraform/remote_state.tf` reads `platform-workloads` state. Preserve the shapes of outputs in `terraform/outputs.tf` because other platform repositories consume them.

Terraform compatibility is defined by `terraform/providers.tf`; preserve its reviewed AzureRM/Cloudflare bounds. Commit each root's `.terraform-version` and `.terraform.lock.hcl`. Select the exact root CLI pin before invoking Terraform; normal initialization uses `-lockfile=readonly`. Regenerate provider selections only in a reviewed dependency-update PR; never commit state, plans, or `.terraform/`.

## Validation and planning

For Terraform or Terraform-owned JSON changes:

```pwsh
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform init -backend=false -lockfile=readonly
terraform -chdir=terraform validate
```

Run `git diff --check` for every change. Markdown or Copilot-configuration-only changes do not require Terraform validation.

Use repository workflows for state-backed plans and all applies:

- PRs receive a dev plan when ready for review.
- Add `run-prd-plan` only when a production plan is required.
- Never run a local apply, direct import, targeted apply, or state move/removal.

## Universal constraints

- Azure authentication and state access use OIDC/Azure AD; never add client secrets or credentials.
- Do not commit discovered Cloudflare identifiers, generated state, or plans. Commit the reviewed root provider lock.
- Cloudflare adoption is protected and fail-closed; follow [development workflows](../docs/development-workflows.md) before changing ownership or import behavior.
- Treat provider, backend, environment, output, DNS-zone ownership, and remote-state changes as high blast radius.

See the [architecture overview](../docs/architecture-overview.md) and [development workflows](../docs/development-workflows.md) for detailed repository behavior.
