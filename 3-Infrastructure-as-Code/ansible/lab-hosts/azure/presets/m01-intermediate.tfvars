# Lab 1.I — patterns, --limit and facts need more groups: a staging db host joins
# Lab 1.I — motifs, --limit et faits : un hôte db en staging s'ajoute
module_tag = "01-fundamentals"
access     = "ssh"
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  web2 = { os = "ubuntu", role = "web", environment = "staging" }
  app1 = { os = "almalinux", role = "app", environment = "dev" }
  db1  = { os = "almalinux", role = "db", environment = "staging" }
}
