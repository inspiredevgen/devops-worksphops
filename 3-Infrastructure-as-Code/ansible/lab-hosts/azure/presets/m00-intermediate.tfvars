# Lab 0.I-AZ — a small fleet: 2 Ubuntu web servers + 1 AlmaLinux app server / un petit parc
module_tag = "00-setup"
access     = "ssh"
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  web2 = { os = "ubuntu", role = "web", environment = "dev" }
  app1 = { os = "almalinux", role = "app", environment = "dev" }
}
