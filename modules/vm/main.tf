# Public IP: only created when var.public_ip is true.
# count = 1 makes one copy, count = 0 makes none. That is why it is referred to as [0] below.
resource "azurerm_public_ip" "this" {
  count = var.public_ip ? 1 : 0

  name                = "pip-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# The VM's network card, in the subnet the caller chose.
resource "azurerm_network_interface" "this" {
  name                = "nic-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.public_ip ? azurerm_public_ip.this[0].id : null
  }
}

resource "azurerm_linux_virtual_machine" "this" {
  name                  = "vm-${var.name}"
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = var.size
  tags                  = var.tags
  network_interface_ids = [azurerm_network_interface.this.id]

  admin_username = "azureuser"
  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  boot_diagnostics {}
}
