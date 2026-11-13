# Lab 6.I — validated roles: two web servers + one app server (baseline only)
# Lab 6.I — rôles validés : deux serveurs web + un serveur d'application (baseline seulement)
module_tag = "06-roles"
access     = "ssh"
open_ports = [80]
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  web2 = { os = "almalinux", role = "web", environment = "dev" }
  app1 = { os = "almalinux", role = "app", environment = "dev" }
}
