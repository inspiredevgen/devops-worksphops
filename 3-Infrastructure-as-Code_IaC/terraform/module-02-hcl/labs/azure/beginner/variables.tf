# -----------------------------------------------------------------------------
# EN: Input variables = the "parameters" of your configuration.
# FR: Les variables d'entrée = les « paramètres » de votre configuration.
# -----------------------------------------------------------------------------

variable "subscription_id" {
  description = "EN: Subscription ID (or ARM_SUBSCRIPTION_ID) / FR: ID d'abonnement (ou ARM_SUBSCRIPTION_ID)"
  type        = string
  default     = null
}

variable "location" {
  description = "EN: Azure region / FR: Région Azure"
  type        = string
  default     = "canadacentral"
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

variable "environment" {
  description = "EN: Environment name / FR: Nom de l'environnement"
  type        = string
  default     = "dev"
}

# EN: string restricted to an allow-list (cost control!).
# FR: string limitée à une liste autorisée (contrôle des coûts !).
variable "vm_size" {
  description = "EN: VM size / FR: Taille de la VM"
  type        = string
  default     = "Standard_B1s"

  validation {
    condition     = contains(["Standard_B1s", "Standard_B1ms", "Standard_B2ats_v2", "Standard_B2s"], var.vm_size)
    error_message = "EN: Allowed: Standard_B1s, Standard_B1ms, Standard_B2ats_v2, Standard_B2s. / FR : Autorisées : Standard_B1s, Standard_B1ms, Standard_B2ats_v2, Standard_B2s."
  }
}

variable "admin_username" {
  description = "EN: Linux admin user / FR: Utilisateur administrateur Linux"
  type        = string
  default     = "azureuser"

  validation {
    condition     = !contains(["root", "admin", "administrator"], lower(var.admin_username))
    error_message = "EN: Reserved user names are not allowed. / FR : Les noms d'utilisateur réservés sont interdits."
  }
}

# EN: Path to YOUR public key. Only the PUBLIC key is sent to Azure.
# FR: Chemin vers VOTRE clé publique. Seule la clé PUBLIQUE est envoyée à Azure.
variable "ssh_public_key_path" {
  description = "EN: Path to an SSH public key / FR: Chemin vers une clé SSH publique"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

# EN: number with a range check. 30 GiB is the minimum for Ubuntu images.
# FR: number avec vérification de plage. 30 Gio est le minimum pour les images Ubuntu.
variable "os_disk_size_gb" {
  description = "EN: OS disk size in GiB / FR: Taille du disque OS en Gio"
  type        = number
  default     = 30

  validation {
    condition     = var.os_disk_size_gb >= 30 && var.os_disk_size_gb <= 64
    error_message = "EN: Between 30 and 64 GiB. / FR : Entre 30 et 64 Gio."
  }
}
