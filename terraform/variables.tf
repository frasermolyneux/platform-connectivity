variable "environment" {
  default = "dev"
}

variable "workload_name" {
  description = "Name of the workload as defined in platform-workloads state"
  type        = string
  default     = "platform-connectivity"
}

variable "location" {
  default = "uksouth"
}

variable "instance" {
  default = "01"
}

variable "subscription_id" {}

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

variable "tags" {
  default = {}
}
