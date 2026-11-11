variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

variable "project" {
  description = "EN: Project name (lowercase) / FR: Nom du projet (minuscules)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,15}$", var.project))
    error_message = "EN: 3-16 chars: lowercase, digits, hyphens. / FR : 3 à 16 caractères : minuscules, chiffres, tirets."
  }
}

variable "environment" {
  description = "EN: Target environment / FR: Environnement cible"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "EN: Must be dev, staging or prod. / FR : Doit être dev, staging ou prod."
  }
}

variable "owner" {
  description = "EN: Team or person accountable / FR: Équipe ou personne responsable"
  type        = string
}

# EN: map(string) — extra tags merged into the common tags.
# FR: map(string) — étiquettes supplémentaires fusionnées aux étiquettes communes.
variable "extra_tags" {
  description = "EN: Additional tags / FR: Étiquettes supplémentaires"
  type        = map(string)
  default     = {}
}

# EN: sensitive = true hides the value in plan/apply output.
#     Supply it via the environment: export TF_VAR_api_key="..."
# FR: sensitive = true masque la valeur dans la sortie plan/apply.
#     Fournissez-la par l'environnement : export TF_VAR_api_key="..."
variable "api_key" {
  description = "EN: Third-party API key (sensitive) / FR: Clé d'API tierce (sensible)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.api_key) >= 16
    error_message = "EN: The API key must be at least 16 characters. / FR : La clé d'API doit contenir au moins 16 caractères."
  }
}
