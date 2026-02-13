resource "azurerm_resource_group" "dns" {
  name     = local.dns_resource_group_name
  location = var.location
  tags     = var.tags
}
