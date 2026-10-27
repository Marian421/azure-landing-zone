# --- Which IP address may SSH in ---------------------------------------------

# A data source only LOOKS SOMETHING UP, it builds nothing. This one asks a website
# for the public IPv4 address of the machine running Terraform.
data "http" "my_ip" {
  url = "https://api.ipify.org"
}

locals {
  # "/32" means "exactly this one address". chomp() removes the trailing newline.
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}

# --- Hub: the jump host's subnet ---------------------------------------------

resource "azurerm_network_security_group" "shared" {
  name                = "nsg-shared"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name
  tags                = local.common_tags

  # Lowest priority number is checked first. Everything not allowed here falls through
  # to Azure's default rules, the last of which denies all inbound traffic.
  security_rule {
    name                       = "allow-ssh-from-my-ip"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = local.my_ip_cidr
    destination_address_prefix = "*"
  }
}

# An NSG does nothing until it is attached. This attaches nsg-shared to the hub's subnet.
resource "azurerm_subnet_network_security_group_association" "shared" {
  subnet_id                 = module.network_hub.subnet_ids["snet-shared"]
  network_security_group_id = azurerm_network_security_group.shared.id
}

# --- Spokes: one NSG per spoke, attached to every subnet in that spoke ---------

# One NSG per spoke (nsg-dev, nsg-prod). SSH is allowed only from the hub's address range,
# so the jump host in the hub is the only way in.
resource "azurerm_network_security_group" "spoke" {
  for_each = local.spokes

  name                = "nsg-${each.key}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke[each.key].name
  tags                = local.common_tags

  security_rule {
    name                       = "allow-ssh-from-hub"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = local.hub_address_space
    destination_address_prefix = "*"
  }
}

# The association needs one entry per (spoke, subnet) pair, e.g. dev+snet-web, dev+snet-data, ...
# The nested for builds a list of pairs, flatten() makes it one flat list, and the outer for
# turns it into a map keyed "dev-snet-web" so for_each can use it.
locals {
  spoke_subnets = {
    for pair in flatten([
      for spoke, config in local.spokes : [
        for subnet in keys(config.subnets) : { spoke = spoke, subnet = subnet }
      ]
    ]) : "${pair.spoke}-${pair.subnet}" => pair
  }
}

# Attach each spoke's NSG to each of its subnets.
resource "azurerm_subnet_network_security_group_association" "spoke" {
  for_each = local.spoke_subnets

  subnet_id                 = module.network_spoke[each.value.spoke].subnet_ids[each.value.subnet]
  network_security_group_id = azurerm_network_security_group.spoke[each.value.spoke].id
}
