# Lab 3.I — per-group config on two OS families + cloud metadata / config par groupe sur deux familles d'OS + métadonnées
module_tag = "03-variables"
access     = "ssh"
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  web2 = { os = "ubuntu", role = "web", environment = "prod" }
  app1 = { os = "almalinux", role = "app", environment = "dev" }
}
