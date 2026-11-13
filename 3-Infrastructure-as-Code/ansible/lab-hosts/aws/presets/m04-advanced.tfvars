# Lab 4.A — multi-cloud: the AWS half (apply the Azure half with lab-hosts/azure/presets/m04-advanced.tfvars)
# Lab 4.A — multi-cloud : la moitié AWS (appliquez la moitié Azure avec lab-hosts/azure/presets/m04-advanced.tfvars)
module_tag = "04-dynamic-inventory"
access     = "ssh"
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "prod", tags = { Team = "storefront" } }
  db1  = { os = "al2023", role = "db", environment = "prod", tags = { Team = "payments" } }
}
