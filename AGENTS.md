# platform-connectivity agent brief

## Ownership

This Terraform-only repository owns shared connectivity infrastructure for the Molyneux.IO tenant:

- Azure public DNS zones and records
- Azure Private Link DNS zones
- Cloudflare zone, record, DNSSEC, settings, WAF, backup, and delegation configuration where explicitly enabled
- The per-environment DNS resource group

Do not absorb records or controls owned by workload repositories. Preserve the published `dns_zones`, `dns_resource_group_name`, and `delegated_zone_name_servers` output contracts.

## Main locations

- `terraform/*.tf` - root Terraform configuration
- `terraform/zones/*.json` - public DNS desired state
- `terraform/private_link_zones/*.json` - private endpoint zone lists
- `terraform/tfvars/{dev,prd}.tfvars` - environment inputs
- `terraform/backends/{dev,prd}.backend.hcl` - Azure state backends
- `docs/architecture-overview.md` - ownership and architecture
- `docs/development-workflows.md` - plans, deployments, and Cloudflare adoption

## Targeted validation

For Markdown or Copilot-configuration-only changes:

```pwsh
git diff --check
```

For Terraform or Terraform-owned JSON changes:

```pwsh
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform init -backend=false -upgrade
terraform -chdir=terraform validate
git diff --check
```

Use the PR workflows for state-backed plans. A production plan is opt-in through the `run-prd-plan` label. Never run a local apply.

## Material constraints

- Terraform `>= 1.15.6`; AzureRM `~> 5.0.1`; Cloudflare `~> 5.23.0`.
- Dev intentionally creates only the DNS resource group. Prd enables public zones and Private Link zones through its tfvars.
- State and remote state use Azure AD/OIDC. Do not add credentials, client secrets, or state identifiers discovered at runtime.
- Do not run local `terraform import`, move/remove state, or change state addresses without an explicit migration task.
- `.terraform.lock.hcl` is generated locally and ignored. Provider constraints in `providers.tf` are the committed compatibility boundary.
- Cloudflare adoption is fail-closed through protected repository configuration owned by `platform-workloads`; review `docs/development-workflows.md` before changing adoption or import behavior.
- DNS, provider, backend, output, or environment changes have tenant-wide blast radius and require an appropriate state-backed plan.

Authoritative context: [README](README.md), [architecture](docs/architecture-overview.md), and [development workflows](docs/development-workflows.md).
