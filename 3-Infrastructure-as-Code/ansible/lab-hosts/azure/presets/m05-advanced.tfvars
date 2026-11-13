# Lab 5.A — zero-downtime rolling release: 3 web servers behind a load balancer
# Lab 5.A — livraison progressive sans interruption : 3 serveurs web derrière un équilibreur de charge
module_tag    = "05-control-flow"
access        = "ssh"
open_ports    = [80]
load_balancer = true
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "prod" }
  web2 = { os = "ubuntu", role = "web", environment = "prod" }
  web3 = { os = "almalinux", role = "web", environment = "prod" }
}
