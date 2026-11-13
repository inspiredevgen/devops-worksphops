# Lab 0.A-AWS — the same fleet with NO inbound port: Ansible over SSM / le même parc SANS port entrant : Ansible via SSM
module_tag = "00-setup"
access     = "ssm"
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
  web2 = { os = "ubuntu", role = "web", environment = "dev" }
  app1 = { os = "al2023", role = "app", environment = "dev" }
}
