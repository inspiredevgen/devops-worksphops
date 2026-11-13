# -----------------------------------------------------------------------------
# Lab 0.B-AZ — "Hello, Azure": verify Terraform can authenticate.
# Lab 0.B-AZ — « Bonjour Azure » : vérifier que Terraform peut s'authentifier.
#
# EN: This lab creates NO resources and costs $0. It only reads data.
# FR: Ce lab ne crée AUCUNE ressource et coûte 0 $. Il ne fait que lire des données.
# -----------------------------------------------------------------------------

variable "subscription_id" {
  description = "EN: Azure subscription ID (or set ARM_SUBSCRIPTION_ID) / FR: ID d'abonnement Azure (ou définir ARM_SUBSCRIPTION_ID)"
  type        = string
  default     = null
}

# EN: Who am I? Tenant, subscription and object ID of the signed-in identity.
# FR: Qui suis-je ? Locataire, abonnement et ID d'objet de l'identité connectée.
data "azurerm_client_config" "current" {}

# EN: Details of the subscription the provider targets.
# FR: Détails de l'abonnement ciblé par le provider.
data "azurerm_subscription" "current" {}
