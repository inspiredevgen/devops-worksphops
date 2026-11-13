# Lab 3.B — one template, three environments: one web server per environment, port 80 open to you
# Lab 3.B — un modèle, trois environnements : un serveur web par environnement, port 80 ouvert pour vous
module_tag = "03-variables"
access     = "ssh"
open_ports = [80]
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  web2 = { os = "ubuntu", role = "web", environment = "staging" }
  web3 = { os = "ubuntu", role = "web", environment = "prod" }
}
