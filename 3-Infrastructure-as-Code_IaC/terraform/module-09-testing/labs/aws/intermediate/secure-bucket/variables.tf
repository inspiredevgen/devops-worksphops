# ---------------------------------------------- Layer 1: input validation
# EN: Rejects bad INPUT before anything is planned.
# FR : Rejette les mauvaises ENTRÉES avant toute planification.

variable "name" {
  description = "EN: Bucket name (S3 rules + tf- prefix) / FR: Nom du compartiment (règles S3 + préfixe tf-)"
  type        = string

  validation {
    condition     = can(regex("^tf-[a-z0-9][a-z0-9-]{1,59}[a-z0-9]$", var.name))
    error_message = "EN: 5-63 chars, lowercase letters, digits and hyphens, starting with \"tf-\". / FR : 5 à 63 caractères, minuscules, chiffres et tirets, commençant par « tf- »."
  }
}

variable "environment" {
  description = "EN: dev, stage or prod / FR: dev, stage ou prod"
  type        = string

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "EN: environment must be dev, stage or prod. / FR : environment doit valoir dev, stage ou prod."
  }
}

variable "force_destroy" {
  description = "EN: Allow destroying a non-empty bucket / FR: Autoriser la destruction d'un compartiment non vide"
  type        = bool
  default     = false
}

variable "noncurrent_days" {
  description = "EN: Days to keep old object versions / FR: Jours de conservation des anciennes versions"
  type        = number
  default     = 30

  validation {
    condition     = var.noncurrent_days >= 1 && var.noncurrent_days <= 365 && floor(var.noncurrent_days) == var.noncurrent_days
    error_message = "EN: A whole number of days between 1 and 365. / FR : Un nombre entier de jours entre 1 et 365."
  }
}

variable "kms_key_arn" {
  description = "EN: Optional KMS key; null = SSE-S3 (AES256) / FR: Clé KMS facultative ; null = SSE-S3 (AES256)"
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/.+$", var.kms_key_arn))
    error_message = "EN: Must be a KMS key ARN. / FR : Doit être l'ARN d'une clé KMS."
  }
}
