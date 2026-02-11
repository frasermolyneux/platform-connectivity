# Development Workflows

## Azure DevOps pipelines
- `release-to-production.yml` (scheduled weekly on Thu 03:00 UTC and on `main`) runs Bicep linting, per-environment validate/what-if, then deploy stages for `dev` and `prd` using Azure subscriptions `spn-platform-connectivity-development` and `spn-platform-connectivity-production`.
- `devops-secure-scanning.yml` (scheduled weekly on Thu 02:00 UTC and on `main`/PR) runs the shared DevOps secure scanning template from `frasermolyneux/ado-pipeline-templates`.
- Pipeline templates reside in `.azure-pipelines/templates/` (`bicep-environment-validation.yml` for validate/what-if and `deploy-environment.yml` for `az deployment sub create`).

## Local validation and deployment
1. Authenticate with Azure CLI and ensure access to the target subscription.
2. Validate for an environment (example for dev):
   ```pwsh
   az deployment sub validate \
     --name platformConnectivityDev \
     --template-file bicep/main.bicep \
     --location uksouth \
     --parameters @params/platform.dev.json
   ```
3. Review a what-if:
   ```pwsh
   az deployment sub what-if \
     --name platformConnectivityDev \
     --template-file bicep/main.bicep \
     --location uksouth \
     --parameters @params/platform.dev.json
   ```
4. Deploy when ready:
   ```pwsh
   az deployment sub create \
     --name platformConnectivityDev \
     --template-file bicep/main.bicep \
     --location uksouth \
     --parameters @params/platform.dev.json
   ```

## Conventions
- Keep parameter files in `params/` aligned across environments (`environment`, `location`, `instance`, `tags`).
- Production-only resources are guarded by `environment == 'prd'` checks in `bicep/main.bicep`; avoid toggling these without pipeline/environment updates.
- Tag changes flow automatically into resource groups and zones; keep `Git` pointing at the repo URL for traceability.
