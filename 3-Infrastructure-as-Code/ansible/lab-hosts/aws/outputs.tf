output "hosts" {
  description = "EN: Name → public IP (ssh), private IP (proxyjump) or instance ID (ssm) / FR: Nom → IP publique, IP privée ou ID d'instance"
  value       = { for n, i in aws_instance.host : n => local.ssh ? i.public_ip : local.proxyjump ? i.private_ip : i.id }
}

output "inventory_path" {
  value = var.inventory_path == null ? null : local_file.inventory[0].filename
}

output "operator_role_arn" {
  description = "EN: ssm mode: put this in an AWS profile (see the guide) / FR : mode ssm : à mettre dans un profil AWS"
  value       = local.ssm ? aws_iam_role.operator[0].arn : null
}

output "jump_public_ip" {
  description = "EN: proxyjump mode: ssh ubuntu@<this> / FR: mode proxyjump : ssh ubuntu@<ceci>"
  value       = local.proxyjump ? aws_instance.jump[0].public_ip : null
}

output "lb_address" {
  description = "EN: load_balancer: the ALB DNS name / FR : load_balancer : le nom DNS de l'ALB"
  value       = local.lb ? aws_lb.web[0].dns_name : null
}

# EN: Module 7: a STRUCTURED handoff to Ansible. A playbook reads it (cloud.terraform.terraform_output) and builds
#     its inventory with add_host: no file written, no tag needed.
# FR : Module 7 : un passage de relais STRUCTURÉ vers Ansible. Un playbook le lit (cloud.terraform.terraform_output)
#     et construit son inventaire avec add_host : aucun fichier écrit, aucune étiquette nécessaire.
output "ansible_hosts" {
  description = "EN: name → connection data and groups / FR : nom → données de connexion et groupes"
  value = {
    for n, i in aws_instance.host : n => {
      address     = local.proxyjump ? i.private_ip : (local.ssm ? i.id : i.public_ip)
      user        = local.login_user[var.hosts[n].os]
      role        = var.hosts[n].role
      environment = var.hosts[n].environment
      os          = var.hosts[n].os
      instance_id = i.id
    }
  }
}

output "scale_set_name" {
  value = local.asg ? aws_autoscaling_group.web[0].name : null
}
