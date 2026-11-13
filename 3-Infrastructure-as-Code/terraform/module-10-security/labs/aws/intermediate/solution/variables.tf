variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

variable "owner" {
  description = "EN: Owner tag (required by our custom policy) / FR: Étiquette Owner (exigée par notre politique personnalisée)"
  type        = string
  default     = "platform-team"
}

variable "app_ingress_cidr" {
  description = "EN: The only network allowed to reach the app on 443 / FR: Le seul réseau autorisé à joindre l'application sur 443"
  type        = string
  default     = "10.0.0.0/8"

  validation {
    condition     = can(cidrhost(var.app_ingress_cidr, 0)) && var.app_ingress_cidr != "0.0.0.0/0"
    error_message = "EN: A private CIDR, never 0.0.0.0/0. / FR : Un CIDR privé, jamais 0.0.0.0/0."
  }
}
