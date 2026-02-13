# Copilot Instructions

## Project Overview

Terraform-only repository that provisions platform connectivity infrastructure on Azure: DNS resource groups, public DNS zones with records, and Azure Private Link DNS zones for the Molyneux.IO tenant.

## Technology Stack

- **Infrastructure**: Terraform >= 1.14.3 with azurerm ~> 4.59
- **Cloud**: Microsoft Azure (DNS Zones, Private DNS Zones)
- **CI/CD**: GitHub Actions with OIDC authentication to Azure
- **State**: Remote state in Azure Storage; depends on platform-workloads remote state

## Repository Structure

- `terraform/` — All Terraform configuration files (root module)
- `terraform/zones/` — JSON files defining public DNS zones and their records (one file per domain)
- `terraform/private_link_zones/` — JSON files defining private link zone lists per environment
- `terraform/backends/` — Backend configuration files (dev.backend.hcl, prd.backend.hcl)
- `terraform/tfvars/` — Variable files per environment (dev.tfvars, prd.tfvars)
- `.github/workflows/` — CI/CD workflow definitions
- `docs/` — Project documentation

## Key Patterns

- **JSON-driven DNS zones**: Each domain is defined in a JSON file under `terraform/zones/` containing the zone name and all its records. Terraform dynamically loads these files and creates resources.
- **Environment gating**: Dev creates only the resource group (no `dns_zones_path` set). Prd creates everything (zones, records, private link zones) by setting `dns_zones_path` and `private_link_zones_file` in tfvars.
- Resource group naming: `rg-platform-dns-{environment}-{location}-{instance}`
- Tags (`Environment`, `Workload`, `DeployedBy`, `Git`) are applied via tfvars

## Adding a New DNS Zone

1. Create a JSON file under `terraform/zones/` (e.g., `newdomain.com.json`)
2. Follow the schema: `name`, `a_records`, `aaaa_records`, `cname_records`, `mx_records`, `txt_records`, `srv_records`
3. The zone and its records will be automatically picked up by Terraform

## Adding a New Private Link Zone

1. Add the zone name to the appropriate environment JSON file in `terraform/private_link_zones/`

## Workflow Summary

- **build-and-test**: Runs Terraform plan for Dev on feature branch pushes
- **pr-verify**: Validates PRs with Dev plan; Prd plan requires `run-prd-plan` label
- **deploy-dev**: Manual dispatch for Dev plan+apply
- **deploy-prd**: Triggered on main push, weekly schedule, or manual dispatch; applies Dev then Prd
- **codequality**: Scheduled code quality scanning
- **dependabot-automerge**: Auto-merges Dependabot PRs
- **destroy-environment**: Manual environment teardown

## Local Development

```bash
terraform -chdir=terraform init -backend-config=backends/dev.backend.hcl
terraform -chdir=terraform plan -var-file=tfvars/dev.tfvars
```

## Coding Guidelines

- Follow HashiCorp Terraform style conventions
- Use `terraform fmt` before committing
- Keep DNS zone JSON files consistent with the established schema
- Provide descriptive variable descriptions and use sensible defaults where appropriate
