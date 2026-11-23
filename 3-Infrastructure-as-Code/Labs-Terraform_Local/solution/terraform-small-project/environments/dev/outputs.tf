output "vpc_id" {
  value = module.network.vpc_id
}

output "app_url" {
  description = "Open this in your browser"
  value       = module.app_service.app_url
}

output "web_private_ip" {
  value = module.app_service.private_ip
}

output "bastion_public_ip" {
  value = module.bastion.public_ip
}

output "deployed_app_version" {
  value = var.app_version
}

output "ssh_command" {
  description = "SSH to the web server THROUGH the bastion (ProxyJump)"
  value       = "ssh -i ${trimsuffix(var.ssh_public_key_path, ".pub")} -J ec2-user@${module.bastion.public_ip} ec2-user@${module.app_service.private_ip}"
}
