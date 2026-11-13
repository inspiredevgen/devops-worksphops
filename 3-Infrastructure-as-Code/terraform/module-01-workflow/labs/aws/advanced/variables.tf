variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

# EN: A security group's description cannot be changed in place → forces REPLACE.
#     Used to demonstrate create_before_destroy.
# FR: La description d'un groupe de sécurité ne peut pas être modifiée sur place →
#     force un REMPLACEMENT. Sert à démontrer create_before_destroy.
variable "sg_description" {
  description = "EN: Security group description / FR: Description du groupe de sécurité"
  type        = string
  default     = "Lab 1.A web SG - v1"
}

# EN: Bumping the release resets the app config (replace_triggered_by).
# FR: Changer la version réinitialise la configuration de l'appli (replace_triggered_by).
variable "release_version" {
  description = "EN: Application release / FR: Version de l'application"
  type        = string
  default     = "1.0.0"

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.release_version))
    error_message = "EN: Use semantic versioning, e.g. 1.2.3. / FR : Utilisez le versionnage sémantique, ex. 1.2.3."
  }
}
