# Copilot Instructions

> Shared conventions: see [`.github-copilot/.github/instructions/terraform.instructions.md`](../../.github-copilot/.github/instructions/terraform.instructions.md) (sibling repo) for the standard Terraform layout, providers, remote-state pattern, validation commands, and CI/CD workflows.

## Project Overview

Terraform-only repository that provisions platform connectivity infrastructure on Azure: DNS resource groups, public DNS zones with records, and Azure Private Link DNS zones for the Molyneux.IO tenant.

## Repository Specifics

- `terraform/zones/` — JSON files defining public DNS zones and their records (one file per domain).
- `terraform/private_link_zones/` — JSON files defining private link zone lists per environment.

## Key Patterns

- **JSON-driven DNS zones**: Each domain is defined in a JSON file under `terraform/zones/` containing the zone name and all its records. Terraform dynamically loads these files and creates resources.
- **Environment gating**: Dev creates only the resource group (no `dns_zones_path` set). Prd creates everything (zones, records, private link zones) by setting `dns_zones_path` and `private_link_zones_file` in tfvars.
- Resource group naming: `rg-platform-dns-{environment}-{location}-{instance}`.

## Adding a New DNS Zone

1. Create a JSON file under `terraform/zones/` (e.g., `newdomain.com.json`).
2. Follow the schema: `name`, `a_records`, `aaaa_records`, `cname_records`, `mx_records`, `txt_records`, `srv_records`.
3. The zone and its records will be automatically picked up by Terraform.

## Adding a New Private Link Zone

1. Add the zone name to the appropriate environment JSON file in `terraform/private_link_zones/`.
