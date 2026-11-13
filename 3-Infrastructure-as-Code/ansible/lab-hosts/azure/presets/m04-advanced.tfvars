# Lab 4.A — multi-cloud: the Azure half (apply the AWS half with lab-hosts/aws/presets/m04-advanced.tfvars)
# Lab 4.A — multi-cloud : la moitié Azure (appliquez la moitié AWS avec lab-hosts/aws/presets/m04-advanced.tfvars)
module_tag = "04-dynamic-inventory"
access     = "ssh"
hosts = {
  web2 = { os = "ubuntu", role = "web", environment = "prod", tags = { Team = "storefront" } }
  app1 = { os = "almalinux", role = "app", environment = "prod", tags = { Team = "payments" } }
}
