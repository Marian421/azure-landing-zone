# Resource group for the hub: shared things live here. Separate from tr-lab (the state account)
# so destroying the lab can never touch the state storage.
resource "azurerm_resource_group" "hub" {
  name     = "rg-hub"
  location = var.location
  tags     = local.common_tags
}

module "network_hub" {
  source = "./modules/network"

  name                = "vnet-hub"
  resource_group_name = azurerm_resource_group.hub.name
  location            = var.location
  address_space       = local.hub_address_space
  subnets             = { "snet-shared" = 0 }
  tags                = local.common_tags
}

# One resource group per spoke: rg-dev and rg-prod.
resource "azurerm_resource_group" "spoke" {
  for_each = local.spokes

  name     = "rg-${each.key}"
  location = var.location
  tags     = local.common_tags
}

# The same network module, called once per spoke.
module "network_spoke" {
  source   = "./modules/network"
  for_each = local.spokes

  name                = "vnet-${each.key}"
  resource_group_name = azurerm_resource_group.spoke[each.key].name
  location            = var.location
  address_space       = each.value.address_space
  subnets             = each.value.subnets
  tags                = local.common_tags
}
