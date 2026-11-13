variable "zone_name" {
  description = "EN: A public hosted zone YOU own in Route 53, e.g. example.com / FR: Une zone hébergée publique qui VOUS appartient, ex. example.com"
  type        = string
}

variable "record_name" {
  description = "EN: Sub-domain for the app / FR: Sous-domaine de l'application"
  type        = string
  default     = "app"
}

variable "aws_alb_dns_name" {
  description = "EN: terraform -chdir=../../aws/prod output -raw alb_dns_name"
  type        = string
}

variable "aws_alb_zone_id" {
  description = "EN: terraform -chdir=../../aws/prod output -raw alb_zone_id"
  type        = string
}

variable "azure_ip" {
  description = "EN: terraform -chdir=../../azure/prod output -raw public_ip"
  type        = string

  validation {
    condition     = can(cidrhost("${var.azure_ip}/32", 0))
    error_message = "EN: An IPv4 address. / FR : Une adresse IPv4."
  }
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
