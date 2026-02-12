# Copilot Instructions

## Project Overview

This repository contains subscription-scope Bicep templates that build platform connectivity for MX. It provisions DNS resource groups, Azure Private Link DNS zones, and public DNS zones for platform domains.

## Architecture

- `bicep/main.bicep` is the orchestrator; it is deployed at subscription scope.
- `bicep/modules/privateDnsZone.bicep` is a reusable module for private DNS zones.
- `bicep/zones/` contains one Bicep file per public domain (e.g. `molyneux.io.bicep`, `xtremeidiots.com.bicep`).
- `params/platform.dev.json` and `params/platform.prd.json` supply `environment`, `location`, `instance`, and `tags` parameters.

## Environment Gating

- Most resources (private link zones and public domain zones) deploy only when `environment == 'prd'`.
- Dev deployments primarily validate templates without provisioning DNS zones.
- Resource group naming pattern: `rg-platform-dns-{environment}-{location}-{instance}`.

## Build and Validation Commands

- Lint/build: `az bicep build --file bicep/main.bicep`
- Validate: `az deployment sub validate --location uksouth --template-file bicep/main.bicep --parameters @params/platform.dev.json`
- What-if: `az deployment sub what-if --location uksouth --template-file bicep/main.bicep --parameters @params/platform.dev.json`
- Deploy: `az deployment sub create --location uksouth --template-file bicep/main.bicep --parameters @params/platform.dev.json`

## CI/CD Pipelines

- GitHub Actions workflows are in `.github/workflows/`. Key workflows: `build-and-test.yml` (lint on feature branches), `pr-verify.yml` (lint on PRs), `codequality.yml` (secure scanning and dependency review), `deploy-dev.yml` and `deploy-prd.yml` (deployment).
- Azure DevOps pipelines in `.azure-pipelines/` use templates from `frasermolyneux/ado-pipeline-templates`.

## Conventions

- `uniqueString('connectivity', environment, instance)` seeds deployment prefixes; preserve this pattern when adding modules.
- Tags (`Environment`, `Workload`, `DeployedBy`, `Git`) are applied from parameter files; keep them consistent.
- To add a new public DNS zone: create a Bicep file under `bicep/zones/`, reference it from `bicep/main.bicep` with an `if (environment == 'prd')` guard.
- To add a new private link zone: append to the `privateLinkZones` array in `bicep/main.bicep`.
- Keep files ASCII. Do not change subscription-scope or parameter shapes without updating both params files and pipeline definitions.
