variable "primary_region" {
  description = "EN: Primary region / FR: Région principale"
  type        = string
  default     = "ca-central-1"
}

# EN: ca-west-1 (Calgary) is an OPT-IN region: enable it under Account → AWS Regions first,
#     or use an always-on region such as us-east-2.
# FR : ca-west-1 (Calgary) est une région À ACTIVER : activez-la d'abord dans Compte → Régions AWS,
#     ou utilisez une région toujours active comme us-east-2.
variable "secondary_region" {
  description = "EN: Secondary (DR) region / FR: Région secondaire (reprise)"
  type        = string
  default     = "ca-west-1"
}

variable "primary_cidr" {
  type    = string
  default = "10.82.0.0/16"
}

variable "secondary_cidr" {
  type    = string
  default = "10.83.0.0/16"
}
