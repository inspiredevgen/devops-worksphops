# Lab 1.B — day-one operations on a small fleet / opérations de base sur un petit parc
module_tag = "01-fundamentals"
access     = "ssh"
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  web2 = { os = "ubuntu", role = "web", environment = "dev" }
  app1 = { os = "al2023", role = "app", environment = "dev" }
}
