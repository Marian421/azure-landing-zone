output "vm_id" {
  description = "ID of the VM"
  value       = azurerm_linux_virtual_machine.this.id
}

output "private_ip" {
  description = "Private address of the VM inside its subnet"
  value       = azurerm_network_interface.this.private_ip_address
}

output "public_ip" {
  description = "Public address of the VM, or null when it has none"
  value       = var.public_ip ? azurerm_public_ip.this[0].ip_address : null
}
