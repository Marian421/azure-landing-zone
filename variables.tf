variable "subscription_id" {
  description = "Azure subscription to deploy into"
  type        = string
}

variable "location" {
  description = "Azure region for everything in the project"
  type        = string
  default     = "austriaeast"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key installed on the VMs (the .pub file, never the private key)"
  type        = string
  default     = "~/.ssh/id_ed25519_lab.pub"
}
