output "vpc_id" {
  value = module.network.vpc_id
}

# TODO (Phase 3): add outputs app_url, web_private_ip, bastion_public_ip,
# deployed_app_version and ssh_command (ssh -i <key> -J ec2-user@<bastion> ec2-user@<web private ip>)
