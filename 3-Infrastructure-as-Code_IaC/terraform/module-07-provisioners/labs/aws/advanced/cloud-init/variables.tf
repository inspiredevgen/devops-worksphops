variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

variable "my_ip" {
  description = "EN: Your public IPv4 (no /32) / FR: Votre IPv4 publique (sans /32)"
  type        = string

  validation {
    condition     = can(cidrhost("${var.my_ip}/32", 0))
    error_message = "EN: A plain IPv4 address. / FR : Une adresse IPv4 simple."
  }
}

variable "environment" {
  description = "EN: Environment label shown on the page / FR: Environnement affiché sur la page"
  type        = string
  default     = "dev"
}
