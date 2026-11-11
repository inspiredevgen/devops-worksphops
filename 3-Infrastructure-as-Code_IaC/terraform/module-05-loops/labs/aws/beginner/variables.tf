variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

variable "bucket_count" {
  description = "EN: How many numbered buckets (0-5) / FR: Nombre de compartiments numérotés (0-5)"
  type        = number
  default     = 2

  validation {
    condition     = var.bucket_count >= 0 && var.bucket_count <= 5
    error_message = "EN: Between 0 and 5. / FR : Entre 0 et 5."
  }
}

variable "bucket_names" {
  description = "EN: Named buckets — ORDER MATTERS with count! / FR: Compartiments nommés — l'ORDRE COMPTE avec count !"
  type        = list(string)
  default     = ["logs", "assets", "backups"]

  validation {
    condition     = alltrue([for n in var.bucket_names : can(regex("^[a-z][a-z0-9-]{1,20}$", n))])
    error_message = "EN: Lowercase names, 2-21 chars. / FR : Noms en minuscules, 2 à 21 caractères."
  }
}

variable "create_audit_bucket" {
  description = "EN: Create the optional audit bucket? / FR: Créer le compartiment d'audit optionnel ?"
  type        = bool
  default     = false
}
