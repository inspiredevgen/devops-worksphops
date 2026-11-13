# Lab 2.I — web tier + monitoring on a mixed fleet / tier web + supervision sur un parc mixte
module_tag = "02-playbooks"
access     = "ssh"
open_ports = [80]
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  web2 = { os = "ubuntu", role = "web", environment = "dev" }
  app1 = { os = "al2023", role = "app", environment = "dev" }
}
