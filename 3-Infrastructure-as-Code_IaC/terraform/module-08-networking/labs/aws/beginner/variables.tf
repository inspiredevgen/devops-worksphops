variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

variable "vpc_cidr" {
  description = "EN: VPC address space (/16 recommended) / FR: Espace d'adressage du VPC (/16 recommandé)"
  type        = string
  default     = "10.80.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) <= 20
    error_message = "EN: A valid CIDR of /20 or larger, e.g. 10.80.0.0/16. / FR : Un CIDR valide de /20 ou plus grand, ex. 10.80.0.0/16."
  }
}

variable "az_count" {
  description = "EN: Number of Availability Zones (1-3) / FR: Nombre de zones de disponibilité (1-3)"
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 3
    error_message = "EN: az_count must be 1, 2 or 3. / FR : az_count doit valoir 1, 2 ou 3."
  }
}

# EN: A NAT gateway costs ~5 cents/hour + data. Keep it off unless you test it.
# FR : Une passerelle NAT coûte ~5 cents/heure + données. Laissez-la désactivée sauf pour la tester.
variable "enable_nat" {
  description = "EN: Create one NAT gateway for private subnets / FR: Créer une passerelle NAT pour les sous-réseaux privés"
  type        = bool
  default     = false
}
