# Lab 6.A — a project consuming the versioned collection (same fleet as 6.I)
# Lab 6.A — un projet qui utilise la collection versionnée (même parc que 6.I)
module_tag = "06-roles"
access     = "ssh"
open_ports = [80]
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  web2 = { os = "almalinux", role = "web", environment = "dev" }
  app1 = { os = "almalinux", role = "app", environment = "dev" }
}
