# Lab 7.I — Ansible drives Terraform (reviewed plan), then reads the state as its inventory
# Lab 7.I — Ansible pilote Terraform (plan revu), puis lit l'état comme inventaire
module_tag = "07-terraform"
access     = "ssh"
open_ports = [80]
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  app1 = { os = "almalinux", role = "app", environment = "dev" }
}
