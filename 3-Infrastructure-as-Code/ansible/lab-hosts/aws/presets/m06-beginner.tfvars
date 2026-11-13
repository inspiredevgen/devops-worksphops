# Lab 6.B — the web playbook as a role: Ubuntu + al2023 web servers / le playbook web en rôle
module_tag = "06-roles"
access     = "ssh"
open_ports = [80]
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  web2 = { os = "al2023", role = "web", environment = "dev" }
}
