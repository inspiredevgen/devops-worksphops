# EN: Each variable is designed to trigger a DIFFERENT kind of plan action.
# FR: Chaque variable est conçue pour déclencher un type d'action DIFFÉRENT dans le plan.

variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

# EN: Changing this → bucket name changes → REPLACE (-/+), cascading to dependents.
# FR: Modifier ceci → le nom du compartiment change → REMPLACEMENT (-/+), en cascade.
variable "bucket_prefix" {
  description = "EN: Bucket name prefix / FR: Préfixe du nom du compartiment"
  type        = string
  default     = "tf-lab-m01-int"
}

# EN: Changing this → only a tag changes → UPDATE IN-PLACE (~).
# FR: Modifier ceci → seule une étiquette change → MISE À JOUR SUR PLACE (~).
variable "environment" {
  description = "EN: Environment tag / FR: Étiquette d'environnement"
  type        = string
  default     = "dev"
}

# EN: Changing this → object content changes → UPDATE IN-PLACE (~) of one object.
# FR: Modifier ceci → le contenu de l'objet change → MISE À JOUR SUR PLACE (~) d'un objet.
variable "welcome_message" {
  description = "EN: Content of README.txt / FR: Contenu de README.txt"
  type        = string
  default     = "Hello from Terraform! / Bonjour de Terraform !"
}
