# Lab 0.I-AWS — a small fleet: 2 Ubuntu web servers + 1 Amazon Linux app server / un petit parc
module_tag = "00-setup"
access     = "ssh"
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  web2 = { os = "ubuntu", role = "web", environment = "dev" }
  app1 = { os = "al2023", role = "app", environment = "dev" }
}
