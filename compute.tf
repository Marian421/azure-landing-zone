# --- The jump host: a VM in the hub that is the only way into the spokes ------

module "jump" {
  source = "./modules/vm"

  name                = "jump"
  resource_group_name = azurerm_resource_group.hub.name
  location            = var.location
  subnet_id           = module.network_hub.subnet_ids["snet-shared"]
  public_ip           = true
  ssh_public_key      = file(pathexpand(var.ssh_public_key_path))
  tags                = local.common_tags
}

module "dev-web" {
  source = "./modules/vm"

  name                = "dev-web"
  resource_group_name = azurerm_resource_group.spoke["dev"].name
  location            = var.location
  subnet_id           = module.network_spoke["dev"].subnet_ids["snet-web"]
  ssh_public_key      = file(pathexpand(var.ssh_public_key_path))
  tags                = local.common_tags
}
