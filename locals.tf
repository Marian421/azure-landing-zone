locals {
  common_tags = {
    project = "azure-landing-zone"
    purpose = "landing-zone-lab"
    owner   = "marian"
  }

  # The two spoke networks: environment => its address range and subnets (name => slice number).
  spokes = {
    dev = {
      address_space = "10.1.0.0/16"
      subnets       = { "snet-web" = 0, "snet-data" = 1 }
    }
    prod = {
      address_space = "10.2.0.0/16"
      subnets       = { "snet-web" = 0, "snet-data" = 1 }
    }
  }

  hub_address_space = "10.0.0.0/16"
}
