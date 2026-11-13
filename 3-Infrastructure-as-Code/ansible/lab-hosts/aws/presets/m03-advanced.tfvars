# Lab 3.A — configuration built from instance TAGS / configuration construite à partir des ÉTIQUETTES
module_tag = "03-variables"
access     = "ssh"
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "prod", tags = { Team = "storefront", Backup = "none", Monitoring = "on" } }
  web2 = { os = "ubuntu", role = "web", environment = "dev", tags = { Team = "storefront", Backup = "none", Monitoring = "off" } }
  app1 = { os = "al2023", role = "app", environment = "prod", tags = { Team = "payments", Backup = "daily", Monitoring = "on" } }
  db1  = { os = "al2023", role = "db", environment = "prod", tags = { Team = "payments", Backup = "hourly", Monitoring = "on" } }
}
