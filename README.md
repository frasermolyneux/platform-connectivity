# Platform Connectivity

[![Build and Test](https://github.com/frasermolyneux/platform-connectivity/actions/workflows/build-and-test.yml/badge.svg)](https://github.com/frasermolyneux/platform-connectivity/actions/workflows/build-and-test.yml)
[![Code Quality](https://github.com/frasermolyneux/platform-connectivity/actions/workflows/codequality.yml/badge.svg)](https://github.com/frasermolyneux/platform-connectivity/actions/workflows/codequality.yml)
[![PR Verify](https://github.com/frasermolyneux/platform-connectivity/actions/workflows/pr-verify.yml/badge.svg)](https://github.com/frasermolyneux/platform-connectivity/actions/workflows/pr-verify.yml)
[![Deploy Dev](https://github.com/frasermolyneux/platform-connectivity/actions/workflows/deploy-dev.yml/badge.svg)](https://github.com/frasermolyneux/platform-connectivity/actions/workflows/deploy-dev.yml)
[![Deploy Prd](https://github.com/frasermolyneux/platform-connectivity/actions/workflows/deploy-prd.yml/badge.svg)](https://github.com/frasermolyneux/platform-connectivity/actions/workflows/deploy-prd.yml)

## Documentation

* [Development Workflows](docs/development-workflows.md) - Branch strategy, CI/CD triggers, and development flows
* [Architecture Overview](docs/architecture-overview.md) - High level architecture diagrams and explanations of major components

## Overview

Terraform-managed platform connectivity for the Molyneux.IO tenant. Provisions a DNS resource group per environment, production-only Azure Private Link DNS zones for common private endpoints, and public DNS zones for platform domains using a JSON-driven configuration approach. GitHub Actions workflows handle plan, apply, and deployment gating across dev and prd environments with OIDC authentication to Azure.

## Contributing

Please read the [contributing](CONTRIBUTING.md) guidance; this is a learning and development project.

## Security

Please read the [security](SECURITY.md) guidance; I am always open to security feedback through email or opening an issue.

## Local dev: MCP wire-up

This repo is wired to the org `frasermolyneux-copilot` MCP server, which exposes the shared instruction/prompt/agent catalog from [`frasermolyneux/.github-copilot`](https://github.com/frasermolyneux/.github-copilot) pinned to `v0.1.0`. The coding-agent runner config lives in [`.github/copilot/mcp_config.json`](.github/copilot/mcp_config.json) and is built by [`.github/workflows/copilot-setup-steps.yml`](.github/workflows/copilot-setup-steps.yml). See `.github-copilot/mcp-server/README.md` (in the sibling repo) for the full tool surface, content-root resolution, and per-client wire-up snippets.
