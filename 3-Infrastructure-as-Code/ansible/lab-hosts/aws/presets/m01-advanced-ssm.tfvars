# Lab 1.A-AWS (part 2) — the same hosts over SSM, no inbound port / les mêmes hôtes par SSM, sans port entrant
module_tag = "01-fundamentals"
access     = "ssm"
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  web2 = { os = "ubuntu", role = "web", environment = "dev" }
  app1 = { os = "al2023", role = "app", environment = "dev" }
}
