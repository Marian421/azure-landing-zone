output "jump_public_ip" {
  description = "Public IP of the jump host"
  value       = module.jump.public_ip
}

output "jump_ssh_command" {
  description = "Command to SSH into the jump host"
  value       = "ssh -i ~/.ssh/id_ed25519_lab azureuser@${module.jump.public_ip}"
}
