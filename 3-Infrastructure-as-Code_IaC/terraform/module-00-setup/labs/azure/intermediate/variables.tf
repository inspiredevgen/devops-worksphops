variable "subscription_id" {
  description = "EN: Azure subscription ID (or set ARM_SUBSCRIPTION_ID) / FR: ID d'abonnement (ou ARM_SUBSCRIPTION_ID)"
  type        = string
  default     = null
}

variable "sp_display_name" {
  description = "EN: Display name of the app registration / FR: Nom de l'inscription d'application"
  type        = string
  default     = "sp-terraform-lab"
}

variable "role_definition_name" {
  description = "EN: Built-in role to grant (Contributor cannot assign roles) / FR: Rôle intégré à accorder (Contributeur ne peut pas attribuer de rôles)"
  type        = string
  default     = "Contributor"

  validation {
    # EN: Block the roles that can grant access to others.
    # FR: Bloquer les rôles qui peuvent accorder des accès à d'autres.
    condition     = !contains(["Owner", "User Access Administrator", "Role Based Access Control Administrator"], var.role_definition_name)
    error_message = "EN: Privileged roles are not allowed for the lab identity. / FR : Les rôles privilégiés sont interdits pour l'identité du cours."
  }
}

variable "assignment_scope_id" {
  description = <<-EOT
    EN: Scope of the role assignment. null = whole subscription. For tighter
        least privilege, pass a resource group ID.
    FR: Portée de l'attribution de rôle. null = tout l'abonnement. Pour un
        privilège plus restreint, passez l'ID d'un groupe de ressources.
  EOT
  type        = string
  default     = null
}

variable "secret_rotation_days" {
  description = "EN: Client secret lifetime in days / FR: Durée de vie du secret client en jours"
  type        = number
  default     = 90

  validation {
    condition     = var.secret_rotation_days >= 1 && var.secret_rotation_days <= 180
    error_message = "EN: Between 1 and 180 days. / FR : Entre 1 et 180 jours."
  }
}
