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

Terraform-managed shared connectivity for the Molyneux.IO tenant: Azure and Cloudflare DNS, production Private Link zones, and the shared Cloudflare maintenance edge. Public DNS desired state is JSON-driven. GitHub Actions handles plans and deployment across dev and prd using Azure OIDC authentication.

## Contributing

Please read the [contributing](CONTRIBUTING.md) guidance; this is a learning and development project.

## Security

Please read the [security](SECURITY.md) guidance; I am always open to security feedback through email or opening an issue.
