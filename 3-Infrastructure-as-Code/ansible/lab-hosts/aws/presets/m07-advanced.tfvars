# Lab 7.A — day 2: two static web servers (patching, golden AMI) + an Auto Scaling group that Ansible scales
# Lab 7.A — jour 2 : deux serveurs web fixes (correctifs, AMI de référence) + un groupe Auto Scaling mis à l'échelle par Ansible
module_tag = "07-terraform"
access     = "ssh"
open_ports = [80]
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  web2 = { os = "al2023", role = "web", environment = "dev" }
}
scale_set = { capacity = 1 }
