variable "subscription_id" {
  description = "EN: Subscription ID (or ARM_SUBSCRIPTION_ID) / FR: ID d'abonnement (ou ARM_SUBSCRIPTION_ID)"
  type        = string
  default     = null
}

variable "secondary_subscription_id" {
  description = "EN: Optional second subscription for the DR network / FR: Second abonnement facultatif pour le réseau de reprise"
  type        = string
  default     = null
}

variable "primary_location" {
  type    = string
  default = "canadacentral"
}

variable "secondary_location" {
  type    = string
  default = "canadaeast"
}

variable "primary_cidr" {
  type    = string
  default = "10.84.0.0/16"
}

variable "secondary_cidr" {
  type    = string
  default = "10.85.0.0/16"
}
