variable "name" {
  description = "EN: Name prefix / FR: Préfixe de nom"
  type        = string
}

variable "cidr" {
  description = "EN: VPC CIDR (/16-/20) / FR: CIDR du VPC (/16-/20)"
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr, 0)) && tonumber(split("/", var.cidr)[1]) >= 16 && tonumber(split("/", var.cidr)[1]) <= 20
    error_message = "EN: cidr must be a valid /16 to /20. / FR : cidr doit être un /16 à /20 valide."
  }
}

variable "az_count" {
  description = "EN: Number of AZs (1-3) / FR: Nombre d'AZ (1-3)"
  type        = number
  default     = 2
}

variable "public_subnets" {
  description = "EN: Create public subnets + internet gateway / FR: Créer des sous-réseaux publics + passerelle Internet"
  type        = bool
  default     = true
}

variable "s3_gateway_endpoint" {
  description = "EN: Free S3 gateway endpoint for private subnets / FR: Point de terminaison passerelle S3 gratuit pour les sous-réseaux privés"
  type        = bool
  default     = false
}
