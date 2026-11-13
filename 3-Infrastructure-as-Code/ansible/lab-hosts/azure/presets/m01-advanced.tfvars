# Lab 1.A-AZ — private VMs through Azure Bastion tunnels, then measure the tuning
# Lab 1.A-AZ — VM privées par tunnels Azure Bastion, puis mesure des réglages
module_tag = "01-fundamentals"
access     = "bastion"
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  web2 = { os = "ubuntu", role = "web", environment = "dev" }
  app1 = { os = "almalinux", role = "app", environment = "dev" }
}
