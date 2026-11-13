# Lab 4.B — dynamic inventory: no inventory file is written, the cloud API IS the inventory
# Lab 4.B — inventaire dynamique : aucun fichier d'inventaire n'est écrit, l'API cloud EST l'inventaire
module_tag = "04-dynamic-inventory"
access     = "ssh"
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  web2 = { os = "ubuntu", role = "web", environment = "dev" }
  app1 = { os = "al2023", role = "app", environment = "dev" }
}
