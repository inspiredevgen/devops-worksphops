# Lab 0.A-AZ — the same fleet with NO public IP: Ansible through Azure Bastion tunnels
# Lab 0.A-AZ — le même parc SANS IP publique : Ansible par des tunnels Azure Bastion
module_tag = "00-setup"
access     = "bastion"
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  web2 = { os = "ubuntu", role = "web", environment = "dev" }
  app1 = { os = "almalinux", role = "app", environment = "dev" }
}
