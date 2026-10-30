variable "name" {
  description = "Short name, e.g. \"jump\". The VM, NIC and public IP become vm-<name>, nic-<name> and pip-<name>"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group the VM, NIC and public IP go into"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet the VM's network card joins"
  type        = string
}

variable "size" {
  description = "VM size"
  type        = string
  default     = "Standard_B2ats_v2"
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource in the module"
  type        = map(string)
  default     = {}
}

variable "public_ip" {
  description = "Give the VM a public IP address (true for the jump host, false for private VMs)"
  type        = bool
  default     = false
}

variable "ssh_public_key" {
  description = "Content of the SSH public key (one line), installed for the admin user"
  type        = string
}
