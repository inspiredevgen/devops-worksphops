# EN: Production values. Usage: terraform plan -var-file=environments/prod.tfvars
# FR: Valeurs de production. Usage : terraform plan -var-file=environments/prod.tfvars

project     = "hcl-lab"
environment = "prod"
owner       = "platform-team"

extra_tags = {
  costCenter  = "training"
  criticality = "high"
  # EN: Overridden by the mandatory tag in locals.tf. / FR : Écrasé par l'étiquette obligatoire de locals.tf.
  owner = "someone-else"
}
