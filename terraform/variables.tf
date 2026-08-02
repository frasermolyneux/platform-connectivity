variable "environment" {
  description = "Environment name (e.g., dev, prd)"
  type        = string
  default     = "dev"
}

variable "workload_name" {
  description = "Name of the workload as defined in platform-workloads state"
  type        = string
  default     = "platform-connectivity"
}

variable "location" {
  description = "Azure region where resources will be deployed"
  type        = string
  default     = "uksouth"
}

variable "instance" {
  description = "Instance number for resource naming (e.g., 01, 02)"
  type        = string
  default     = "01"
}

variable "subscription_id" {
  description = "Azure subscription ID where resources will be deployed"
  type        = string
}

variable "platform_workloads_state" {
  description = "Backend config for platform-workloads remote state"
  type = object({
    resource_group_name  = string
    storage_account_name = string
    container_name       = string
    key                  = string
    subscription_id      = string
    tenant_id            = string
  })
}

variable "dns_zones_path" {
  description = "Path to the directory containing DNS zone JSON files"
  type        = string
  default     = ""
}

variable "private_link_zones_file" {
  description = "Path to the JSON file containing private link zone names"
  type        = string
  default     = ""
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token used to manage Cloudflare DNS records. Supplied via TF_VAR_cloudflare_api_token (secrets.CLOUDFLARE_API_KEY) in CI; leave empty when no Cloudflare zones are managed."
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID that owns Terraform-managed zones. Required when a zone definition sets management to terraform."
  type        = string
  default     = ""
}

variable "cloudflare_adopted_zone_keys" {
  description = "Zone definition keys approved for Terraform management after inventory and import. Empty by default so declared zones remain inactive until adoption is complete."
  type        = set(string)
  default     = []
}

variable "dns_delegations" {
  description = "Subdomains delegated from a Cloudflare parent zone to a new Azure DNS child zone. Empty by default; add entries to activate delegation. The parent_zone must be a Cloudflare-managed zone in terraform/zones/."
  type = list(object({
    subdomain   = string # e.g. "internal"
    parent_zone = string # Cloudflare zone name, e.g. "xtremeidiots.com"
  }))
  default = []
}

variable "tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
  default     = {}
}
