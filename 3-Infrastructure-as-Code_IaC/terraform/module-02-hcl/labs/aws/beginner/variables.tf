# -----------------------------------------------------------------------------
# EN: Input variables = the "parameters" of your configuration.
#     Each one has a type, a description, an optional default and optional
#     validation rules.
# FR: Les variables d'entrée = les « paramètres » de votre configuration.
#     Chacune a un type, une description, une valeur par défaut optionnelle et
#     des règles de validation optionnelles.
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

# EN: string — no default, so Terraform will ASK for it (or use -var / tfvars).
# FR: string — sans valeur par défaut : Terraform la DEMANDERA (ou -var / tfvars).
variable "project_name" {
  description = "EN: Short project name, lowercase / FR: Nom court du projet, en minuscules"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.project_name))
    error_message = "EN: 3-20 chars, lowercase letters, digits, hyphens; start with a letter. / FR : 3 à 20 caractères, minuscules, chiffres, tirets ; commence par une lettre."
  }
}

# EN: string restricted to an allow-list (cost control!).
# FR: string limitée à une liste autorisée (contrôle des coûts !).
variable "instance_type" {
  description = "EN: EC2 instance type / FR: Type d'instance EC2"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t2.micro", "t3.micro", "t3.small"], var.instance_type)
    error_message = "EN: Allowed: t2.micro, t3.micro, t3.small. / FR : Autorisés : t2.micro, t3.micro, t3.small."
  }
}

# EN: number with a range check.
# FR: number avec une vérification de plage.
variable "root_volume_size_gb" {
  description = "EN: Root disk size in GiB / FR: Taille du disque racine en Gio"
  type        = number
  default     = 8

  validation {
    condition     = var.root_volume_size_gb >= 8 && var.root_volume_size_gb <= 30
    error_message = "EN: Between 8 and 30 GiB. / FR : Entre 8 et 30 Gio."
  }
}

# EN: bool — detailed (1-minute) monitoring costs extra, so default is false.
# FR: bool — la surveillance détaillée (1 minute) coûte plus cher : false par défaut.
variable "enable_detailed_monitoring" {
  description = "EN: Enable 1-minute CloudWatch metrics / FR: Activer les métriques CloudWatch à 1 minute"
  type        = bool
  default     = false
}

variable "environment" {
  description = "EN: Environment name / FR: Nom de l'environnement"
  type        = string
  default     = "dev"
}
