# Lab 2.B — first playbook: nginx on one web server, port 80 open to you
# Lab 2.B — premier playbook : nginx sur un serveur web, port 80 ouvert pour vous
module_tag = "02-playbooks"
access     = "ssh"
open_ports = [80]
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
}
