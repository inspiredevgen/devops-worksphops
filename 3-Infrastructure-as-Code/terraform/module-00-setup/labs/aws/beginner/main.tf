# -----------------------------------------------------------------------------
# Lab 0.B-AWS — "Hello, AWS": verify Terraform can authenticate.
# Lab 0.B-AWS — « Bonjour AWS » : vérifier que Terraform peut s'authentifier.
#
# EN: This lab creates NO resources and costs $0. It only uses DATA SOURCES,
#     which read information from AWS.
# FR: Ce lab ne crée AUCUNE ressource et coûte 0 $. Il utilise uniquement des
#     SOURCES DE DONNÉES, qui lisent de l'information depuis AWS.
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "EN: AWS region to use / FR: Région AWS à utiliser"
  type        = string
  default     = "ca-central-1" # EN: Canada (Central) / FR: Canada (Centre)
}

# EN: Who am I? Returns the account ID and the identity Terraform is using.
# FR: Qui suis-je ? Retourne l'ID du compte et l'identité utilisée par Terraform.
data "aws_caller_identity" "current" {}

# EN: Which region is the provider configured for?
# FR: Pour quelle région le provider est-il configuré ?
data "aws_region" "current" {}

# EN: Which Availability Zones are available in that region?
# FR: Quelles zones de disponibilité sont offertes dans cette région ?
data "aws_availability_zones" "available" {
  state = "available"
}
