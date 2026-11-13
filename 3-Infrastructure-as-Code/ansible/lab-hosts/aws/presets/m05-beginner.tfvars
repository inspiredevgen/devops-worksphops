# Lab 5.B — one playbook, two distros: Ubuntu + al2023 web servers, port 80 open to you
# Lab 5.B — un playbook, deux distributions : serveurs web Ubuntu + al2023, port 80 ouvert pour vous
module_tag = "05-control-flow"
access     = "ssh"
open_ports = [80]
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  web2 = { os = "al2023", role = "web", environment = "dev" }
}
