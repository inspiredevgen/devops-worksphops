# EN: Development values. Usage: terraform plan -var-file=environments/dev.tfvars
# FR: Valeurs de développement. Usage : terraform plan -var-file=environments/dev.tfvars

project     = "hcl-lab"
environment = "dev"
owner       = "platform-team"

extra_tags = {
  CostCenter = "training"
}
