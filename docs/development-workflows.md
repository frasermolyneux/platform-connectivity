# Development Workflows

## GitHub Actions workflows
- **build-and-test**: Runs `terraform plan` for dev on feature/bugfix/hotfix branch pushes.
- **pr-verify**: Validates PRs with a dev plan; apply with `deploy-dev` label; prd plan with `run-prd-plan` label.
- **deploy-dev**: Manual dispatch to run `terraform plan` and `apply` against dev.
- **deploy-prd**: Triggered on push to main, weekly schedule (Thu 03:00 UTC), or manual dispatch. Applies dev first, then prd.
- **codequality**: Scheduled Monday 3am UTC. Runs DevOps secure scanning and dependency review on PRs.
- **destroy-environment**: Manual dispatch with environment choice (dev/prd).

## Local validation and deployment
1. Authenticate with Azure CLI and ensure access to the target subscription.
2. Initialise Terraform (example for dev):
   ```bash
   terraform -chdir=terraform init -backend-config=backends/dev.backend.hcl
   ```
3. Plan:
   ```bash
   terraform -chdir=terraform plan -var-file=tfvars/dev.tfvars
   ```
4. Apply when ready:
   ```bash
   terraform -chdir=terraform apply -var-file=tfvars/dev.tfvars
   ```

## Conventions
- DNS zones are configuration-driven via JSON files in `terraform/zones/`. To add a new domain, create a JSON file following the existing schema.
- Private link zones are listed in `terraform/private_link_zones/prd.json`.
- Production-only resources are gated by tfvars: dev has no `dns_zones_path` set, prd points to the zone configurations.
- Tags are applied from tfvars; keep `Git` pointing at the repo URL for traceability.
