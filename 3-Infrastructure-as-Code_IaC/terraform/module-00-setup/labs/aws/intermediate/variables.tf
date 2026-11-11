variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

variable "role_name" {
  description = "EN: Name of the Terraform lab role / FR: Nom du rôle Terraform du cours"
  type        = string
  default     = "TerraformLabRole"
}

variable "trusted_principal_arns" {
  description = <<-EOT
    EN: IAM principals allowed to assume the role (e.g. your admin IAM user ARN).
        Leave empty to trust the whole account (any principal with sts:AssumeRole permission).
    FR: Principaux IAM autorisés à assumer le rôle (ex. l'ARN de votre utilisateur admin).
        Laissez vide pour faire confiance à tout le compte.
  EOT
  type        = list(string)
  default     = []
}

variable "iam_name_prefix" {
  description = "EN: Prefix the role may use for IAM roles/policies it creates / FR: Préfixe autorisé pour les rôles/politiques IAM créés"
  type        = string
  default     = "tf-"

  validation {
    condition     = can(regex("^[a-zA-Z0-9+=,.@_-]{2,20}$", var.iam_name_prefix))
    error_message = "EN: 2-20 IAM-safe characters. / FR : 2 à 20 caractères valides pour IAM."
  }
}

variable "max_session_hours" {
  description = "EN: Max session duration in hours (1-12) / FR: Durée max de session en heures (1-12)"
  type        = number
  default     = 1

  validation {
    condition     = var.max_session_hours >= 1 && var.max_session_hours <= 12
    error_message = "EN: Must be between 1 and 12. / FR : Doit être entre 1 et 12."
  }
}
