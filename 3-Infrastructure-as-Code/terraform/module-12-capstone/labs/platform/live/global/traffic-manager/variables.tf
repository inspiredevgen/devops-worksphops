variable "subscription_id" {
  description = "EN: Subscription ID (or ARM_SUBSCRIPTION_ID) / FR: ID d'abonnement (ou ARM_SUBSCRIPTION_ID)"
  type        = string
  default     = null
}

variable "location" {
  description = "EN: Region of the resource group (Traffic Manager itself is global) / FR: Région du groupe de ressources (Traffic Manager est mondial)"
  type        = string
  default     = "canadacentral"
}

# EN: Pass the OUTPUTS of the two prod stacks (see the guide):
#       aws_target   = terraform -chdir=../../aws/prod output -raw alb_dns_name
#       azure_target = terraform -chdir=../../azure/prod output -raw fqdn
# FR : Passez les SORTIES des deux piles de prod (voir le guide).
variable "aws_target" {
  description = "EN: AWS ALB DNS name / FR: Nom DNS de l'ALB AWS"
  type        = string
}

variable "azure_target" {
  description = "EN: Azure public IP FQDN / FR: FQDN de l'IP publique Azure"
  type        = string
}

variable "primary" {
  description = "EN: Which cloud serves traffic while healthy / FR: Quel cloud sert le trafic tant qu'il est sain"
  type        = string
  default     = "aws"

  validation {
    condition     = contains(["aws", "azure"], var.primary)
    error_message = "EN: primary must be aws or azure. / FR : primary doit valoir aws ou azure."
  }
}

variable "fast_probing" {
  description = "EN: 10-second probes (faster failover, small extra cost) instead of 30 / FR: sondes de 10 s (bascule plus rapide, petit surcoût) au lieu de 30"
  type        = bool
  default     = true
}
