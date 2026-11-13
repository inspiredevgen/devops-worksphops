# Lab 4.I — two environments in one account: dev and prod, separated by the Environment tag
# Lab 4.I — deux environnements dans un compte : dev et prod, séparés par l'étiquette Environment
module_tag = "04-dynamic-inventory"
access     = "ssh"
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  app1 = { os = "almalinux", role = "app", environment = "dev" }
  web2 = { os = "ubuntu", role = "web", environment = "prod" }
  db1  = { os = "almalinux", role = "db", environment = "prod" }
}
