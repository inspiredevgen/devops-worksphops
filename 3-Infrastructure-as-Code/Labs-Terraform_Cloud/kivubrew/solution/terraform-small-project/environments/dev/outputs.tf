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
  description = "SSH to the web server THROUGH the bastion (ProxyJump). Run it on YOUR laptop: the private key never leaves it."
  value       = "ssh -i ~/.ssh/kivubrew-${var.environment} -J ec2-user@${module.bastion.public_ip} ec2-user@${module.app_service.private_ip}"
}
