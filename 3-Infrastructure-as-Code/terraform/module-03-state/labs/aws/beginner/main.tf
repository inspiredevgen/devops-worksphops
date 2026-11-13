# -----------------------------------------------------------------------------
# Lab 3.B-AWS — Inside the state file
# Lab 3.B-AWS — À l'intérieur du fichier d'état
#
# EN: Three tiny, free resources so you can focus on what Terraform RECORDS.
# FR: Trois ressources minuscules et gratuites pour vous concentrer sur ce que
#     Terraform ENREGISTRE.
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

variable "db_host" {
  description = "EN: Database host name / FR: Nom d'hôte de la base de données"
  type        = string
  default     = "db.internal.example"
}

# EN: A random name — its value exists ONLY in state (no cloud API).
# FR: Un nom aléatoire — sa valeur n'existe QUE dans l'état (aucune API cloud).
resource "random_pet" "app" {
  length = 2
}

resource "aws_ssm_parameter" "db_host" {
  name  = "/tf-lab/m03/${random_pet.app.id}/db-host"
  type  = "String"
  value = var.db_host
}

resource "aws_ssm_parameter" "feature_flags" {
  name = "/tf-lab/m03/${random_pet.app.id}/feature-flags"
  type = "String"
  value = jsonencode({
    new_checkout = false
    dark_mode    = true
  })
}

output "app_name" {
  description = "EN: Generated app name / FR: Nom d'application généré"
  value       = random_pet.app.id
}

output "parameter_names" {
  description = "EN: SSM parameter names / FR: Noms des paramètres SSM"
  value       = [aws_ssm_parameter.db_host.name, aws_ssm_parameter.feature_flags.name]
}
