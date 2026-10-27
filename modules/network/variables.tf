variable "name" {
  description = "Name of the virtual network, e.g. vnet-hub"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group the network is created in"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "address_space" {
  description = "The whole range of the network, e.g. 10.0.0.0/16"
  type        = string
}

variable "subnets" {
  description = "Subnets to create: subnet name => slice number inside the address space (0 gives the first /24, 1 the second, ...)"
  type        = map(number)
}

variable "tags" {
  description = "Tags put on the network"
  type        = map(string)
  default     = {}
}
