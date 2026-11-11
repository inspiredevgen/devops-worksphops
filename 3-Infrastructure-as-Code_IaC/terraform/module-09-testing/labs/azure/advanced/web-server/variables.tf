variable "name" {
  description = "EN: Name suffix (lowercase, digits, hyphens) / FR: Suffixe de nom (minuscules, chiffres, tirets)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,30}$", var.name))
    error_message = "EN: 3-30 lowercase letters, digits or hyphens. / FR : 3 à 30 minuscules, chiffres ou tirets."
  }
}

variable "location" {
  description = "EN: Azure region / FR: Région Azure"
  type        = string
  default     = "canadacentral"
}

variable "allowed_cidr" {
  description = "EN: Who may reach port 80 (never 0.0.0.0/0) / FR: Qui peut joindre le port 80 (jamais 0.0.0.0/0)"
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_cidr, 0)) && var.allowed_cidr != "0.0.0.0/0"
    error_message = "EN: A valid CIDR, and not the whole internet. / FR : Un CIDR valide, et pas tout Internet."
  }
}

variable "ssh_public_key" {
  description = "EN: SSH public key CONTENT (not a path), required by Azure / FR: CONTENU de la clé SSH publique (pas un chemin), exigé par Azure"
  type        = string

  validation {
    condition     = can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256) ", var.ssh_public_key))
    error_message = "EN: Must be an OpenSSH public key. / FR : Doit être une clé publique OpenSSH."
  }
}

variable "message" {
  description = "EN: Text shown on the page / FR: Texte affiché sur la page"
  type        = string
  default     = "Hello from a tested module! / Bonjour depuis un module testé !"
}

variable "vm_size" {
  description = "EN: VM size / FR: Taille de la VM"
  type        = string
  default     = "Standard_B1s"
}
