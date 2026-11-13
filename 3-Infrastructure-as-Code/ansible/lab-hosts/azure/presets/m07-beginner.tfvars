# Lab 7.B — Terraform builds, Ansible reads the ansible_hosts output and configures (no inventory file written)
# Lab 7.B — Terraform construit, Ansible lit la sortie ansible_hosts et configure (aucun fichier d'inventaire écrit)
module_tag = "07-terraform"
access     = "ssh"
open_ports = [80]
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  app1 = { os = "almalinux", role = "app", environment = "dev" }
}
