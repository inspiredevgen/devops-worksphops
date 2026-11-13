# Lab 5.B — one playbook, two distros: Ubuntu + almalinux web servers, port 80 open to you
# Lab 5.B — un playbook, deux distributions : serveurs web Ubuntu + almalinux, port 80 ouvert pour vous
module_tag = "05-control-flow"
access     = "ssh"
open_ports = [80]
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  web2 = { os = "almalinux", role = "web", environment = "dev" }
}
