# Architecture Overview

This repository deploys tenant platform connectivity resources using Terraform.

- A DNS resource group is created per environment/location/instance using the pattern `rg-platform-dns-{environment}-{location}-{instance}`.
- Private DNS zones are provisioned only for production and cover common Azure private endpoints (storage, SQL, ACR, App Service, Service Bus, API Management, etc.). The zone list is defined in `terraform/private_link_zones/prd.json`.
- Public DNS zones for platform domains (e.g., molyneux.dev, molyneux.io, xtremeidiots.com, xtremeidiots.dev, geo-location.net, molyneux.me, molyneux-consulting.co.uk, mx-consulting.co.uk, talkwithtiles.com) are deployed for production. Each domain is defined as a JSON file under `terraform/zones/` containing the zone name and all its DNS records.
- Terraform dynamically loads zone JSON files and creates `azurerm_dns_zone`, record resources (A, AAAA, CNAME, MX, TXT, SRV), and `azurerm_private_dns_zone` resources.
- Environment gating is achieved via tfvars: dev has no `dns_zones_path` set (empty resource group only), while prd points to the zone configurations.
- Remote state from `platform-workloads` is consumed for workload resource group metadata.
- Tags are applied from tfvars, typically including `Environment`, `Workload`, `DeployedBy`, and `Git` for traceability.
