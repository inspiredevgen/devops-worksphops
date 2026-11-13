# Lab 7.A — day 2: one web server (patching), one builder VM (golden image) + a scale set that Ansible scales
# Lab 7.A — jour 2 : un serveur web (correctifs), une VM de construction (image de référence) + un groupe identique mis à l'échelle par Ansible
module_tag = "07-terraform"
access     = "ssh"
open_ports = [80]
hosts = {
  web1     = { os = "ubuntu", role = "web", environment = "dev" }
  builder1 = { os = "ubuntu", role = "builder", environment = "dev" }
}
scale_set = { capacity = 1 }
