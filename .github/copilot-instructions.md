# Copilot Instructions

- Purpose: subscription-scope Bicep that builds platform connectivity for MX (DNS resource group, private link DNS zones, public DNS zones for platform domains).
- Layout: `bicep/main.bicep` orchestrates everything. Private DNS zone module is `bicep/modules/privateDnsZone.bicep`. Public zones live under `bicep/zones/` per domain. Parameter sets per environment in `params/platform.<env>.json` supply `environment`, `location`, `instance`, `tags`.
- Environment gating: Most resources (private link zones and public domains) deploy only when `environment == 'prd'`; dev runs primarily to validate templates. Resource group naming pattern `rg-platform-dns-{environment}-{location}-{instance}`.
- Tags: applied from parameters (`Environment`, `Workload`, `DeployedBy`, `Git`); keep them aligned across environments for traceability.
- Pipelines: Azure DevOps definitions in `.azure-pipelines/`. `release-to-production.yml` runs Bicep lint, validate/what-if (dev & prd), then deploy stages using templates in `.azure-pipelines/templates/`. `devops-secure-scanning.yml` runs weekly/PR secure scanning. Templates `bicep-environment-validation.yml` and `deploy-environment.yml` run `az deployment sub validate/what-if/create`.
- Local loop: authenticate with Azure CLI, then `az deployment sub validate/what-if/create --template-file bicep/main.bicep --location <loc> --parameters @params/platform.dev.json` (or prd) to mirror pipelines.
- Naming/uniqueness: `uniqueString('connectivity', environment, instance)` seeds deployment prefixes to avoid conflicts; preserve this when extending modules.
- Adding zones: define a new module under `bicep/zones/` and reference it from `bicep/main.bicep` with the appropriate environment guard. For additional private link zones, extend `privateLinkZones` array; private zone deployments are scoped to the DNS resource group.
- External dependencies: pipelines import templates from `frasermolyneux/ado-pipeline-templates` via GitHub service connection `github.com_frasermolyneux`; ensure that repo stays reachable when editing pipelines.
- Formatting/testing: use `az bicep build` or Azure CLI validation to catch syntax issues. Keep files ASCII and avoid changing scope/parameter shapes without updating params and pipelines.
