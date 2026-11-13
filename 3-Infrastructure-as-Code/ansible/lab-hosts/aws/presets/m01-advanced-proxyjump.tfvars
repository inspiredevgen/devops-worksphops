# Lab 1.A-AWS (part 1) — private hosts behind ONE jump host / hôtes privés derrière UN hôte de rebond
module_tag = "01-fundamentals"
access     = "proxyjump"
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  web2 = { os = "ubuntu", role = "web", environment = "dev" }
  app1 = { os = "al2023", role = "app", environment = "dev" }
}
