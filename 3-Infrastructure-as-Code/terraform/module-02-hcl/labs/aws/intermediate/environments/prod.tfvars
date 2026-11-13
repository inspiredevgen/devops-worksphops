# EN: Production values. Usage: terraform plan -var-file=environments/prod.tfvars
# FR: Valeurs de production. Usage : terraform plan -var-file=environments/prod.tfvars

project     = "hcl-lab"
environment = "prod"
owner       = "platform-team"

extra_tags = {
  CostCenter  = "training"
  Criticality = "high"
  # EN: Try it: this "Owner" is overridden by the mandatory tag in locals.tf.
  # FR: Essayez : cet « Owner » est écrasé par l'étiquette obligatoire de locals.tf.
  Owner = "someone-else"
}
