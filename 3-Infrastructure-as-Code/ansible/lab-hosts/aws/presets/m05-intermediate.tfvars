# Lab 5.I — block/rescue: automatic rollback of a bad release (same two distros)
# Lab 5.I — block/rescue : retour arrière automatique d'une mauvaise version
module_tag = "05-control-flow"
access     = "ssh"
open_ports = [80]
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  web2 = { os = "al2023", role = "web", environment = "dev" }
}
