output "vnet_id" {
  description = "ID of the virtual network (peering needs it)"
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.this.name
}

output "subnet_ids" {
  description = "Subnet name => subnet ID"
  value       = { for name, subnet in azurerm_subnet.this : name => subnet.id }
}
