# Peering connects two virtual networks. Azure needs it created from BOTH sides:
# one peering living in the hub that points at a spoke, and one living in the spoke that points back.

# Hub side: one peering per spoke, each pointing at that spoke's network.
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = local.spokes

  name                      = "hub-to-${each.key}"
  resource_group_name       = azurerm_resource_group.hub.name
  virtual_network_name      = module.network_hub.vnet_name
  remote_virtual_network_id = module.network_spoke[each.key].vnet_id
}

# Spoke side: one peering per spoke, each pointing back at the hub.
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = local.spokes

  name                      = "${each.key}-to-hub"
  resource_group_name       = azurerm_resource_group.spoke[each.key].name
  virtual_network_name      = module.network_spoke[each.key].vnet_name
  remote_virtual_network_id = module.network_hub.vnet_id
}
