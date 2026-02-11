# Architecture Overview

This repository deploys tenant platform connectivity resources at subscription scope using Bicep.

- Deployment scope is subscription-level; parameters live in `params/platform.<env>.json` with `environment`, `location`, `instance`, and shared `tags`.
- A DNS resource group is created per environment/location/instance using the pattern `rg-platform-dns-{environment}-{location}-{instance}`.
- Private DNS zones are provisioned only for production and cover common Azure private endpoints (storage, SQL, ACR, App Service, Service Bus, API Management, etc.). The list is defined in `bicep/main.bicep` as `privateLinkZones`.
- Public DNS zones for platform domains (e.g., molyneux.dev, molyneux.io, xtremeidiots.com, xtremeidiots.dev, geo-location.net, molyneux.me, molyneux-consulting.co.uk, mx-consulting.co.uk, talkwithtiles.com) are deployed for production via modules under `bicep/zones/`.
- Module composition happens in `bicep/main.bicep`; shared logic for private zones resides in `bicep/modules/privateDnsZone.bicep`.
- Tags are applied from parameter files, typically including `Environment`, `Workload`, `DeployedBy`, and `Git` for traceability.
