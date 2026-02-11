# Platform Connectivity

[![Code Quality](https://github.com/frasermolyneux/platform-connectivity/actions/workflows/codequality.yml/badge.svg)](https://github.com/frasermolyneux/platform-connectivity/actions/workflows/codequality.yml)
[![PR Verify](https://github.com/frasermolyneux/platform-connectivity/actions/workflows/pr-verify.yml/badge.svg)](https://github.com/frasermolyneux/platform-connectivity/actions/workflows/pr-verify.yml)
[![Deploy Dev](https://github.com/frasermolyneux/platform-connectivity/actions/workflows/deploy-dev.yml/badge.svg)](https://github.com/frasermolyneux/platform-connectivity/actions/workflows/deploy-dev.yml)
[![Deploy Prd](https://github.com/frasermolyneux/platform-connectivity/actions/workflows/deploy-prd.yml/badge.svg)](https://github.com/frasermolyneux/platform-connectivity/actions/workflows/deploy-prd.yml)

## Documentation

* [Development Workflows](docs/development-workflows.md) - Branch strategy, CI/CD triggers, and development flows
* [Architecture Overview](docs/architecture-overview.md) - High level architecture diagrams and explanations of major components

## Overview

Subscription-scope Bicep that builds platform connectivity for MX. The deployment creates a DNS resource group per environment/location/instance, production-only private DNS zones for common Azure private link endpoints, and public DNS zones for platform domains via modular Bicep files. Azure DevOps pipelines lint, validate/what-if, and deploy the templates using shared templates from frasermolyneux/ado-pipeline-templates. Parameter files in [params](params) define environment, location, instance, and tags used throughout the deployment.

## Contributing

Please read the [contributing](CONTRIBUTING.md) guidance; this is a learning and development project.

## Security

Please read the [security](SECURITY.md) guidance; I am always open to security feedback through email or opening an issue.
