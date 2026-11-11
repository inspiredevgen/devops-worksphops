variable "name" {
  description = "EN: Name suffix, e.g. capstone-dev / FR: Suffixe de nom, ex. capstone-dev"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,24}$", var.name))
    error_message = "EN: 3-24 lowercase letters, digits or hyphens. / FR : 3 à 24 minuscules, chiffres ou tirets."
  }
}

variable "environment" {
  description = "EN: dev or prod / FR: dev ou prod"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "EN: environment must be dev or prod. / FR : environment doit valoir dev ou prod."
  }
}

variable "location" {
  description = "EN: Azure region (needs availability zones) / FR: Région Azure (avec zones de disponibilité)"
  type        = string
  default     = "canadacentral"
}

# EN: Beginner: the module creates its resource group. CI (Module 11): the pipeline's RG already
#     exists (rg-tf-cicd-<env>) and the apply identity may not create resource groups.
# FR : Débutant : le module crée son groupe de ressources. CI (module 11) : le RG du pipeline existe
#     déjà (rg-tf-cicd-<env>) et l'identité apply ne peut pas créer de groupes de ressources.
variable "resource_group_name" {
  description = "EN: Resource group name / FR: Nom du groupe de ressources"
  type        = string
}

variable "create_resource_group" {
  description = "EN: true = create it; false = use an existing one / FR: true = le créer ; false = utiliser un existant"
  type        = bool
  default     = true
}

variable "vnet_cidr" {
  description = "EN: VNet address space / FR: Espace d'adressage du VNet"
  type        = string

  validation {
    condition     = can(cidrhost(var.vnet_cidr, 0)) && tonumber(split("/", var.vnet_cidr)[1]) <= 20
    error_message = "EN: A valid CIDR of /20 or larger. / FR : Un CIDR valide de /20 ou plus grand."
  }
}

variable "vm_size" {
  description = "EN: VM size / FR: Taille de VM"
  type        = string
  default     = "Standard_B1s"
}

variable "min_instances" {
  description = "EN: Minimum instances / FR: Instances minimum"
  type        = number
  default     = 1
}

variable "max_instances" {
  description = "EN: Maximum instances / FR: Instances maximum"
  type        = number
  default     = 2
}

variable "zones" {
  description = "EN: Availability zones to spread instances over / FR: Zones de disponibilité où répartir les instances"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "allowed_cidrs" {
  description = "EN: Who may reach port 80 / FR: Qui peut joindre le port 80"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_public_key" {
  description = "EN: OpenSSH public key CONTENT (Azure requires one; no SSH port is opened) / FR: CONTENU d'une clé publique OpenSSH (exigée par Azure ; aucun port SSH n'est ouvert)"
  type        = string

  validation {
    condition     = can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256) ", var.ssh_public_key))
    error_message = "EN: Must be an OpenSSH public key. / FR : Doit être une clé publique OpenSSH."
  }
}

variable "app_version" {
  description = "EN: Shown on the page; changing it triggers a rolling upgrade / FR: Affiché sur la page ; le changer déclenche une mise à niveau progressive"
  type        = string
  default     = "1.0.0"

  # EN: The version ends up in a shell command and a sed expression: allow only safe characters.
  # FR : La version finit dans une commande shell et une expression sed : seuls des caractères sûrs.
  validation {
    condition     = can(regex("^[0-9A-Za-z.-]{1,32}$", var.app_version))
    error_message = "EN: 1-32 letters, digits, dots or hyphens. / FR : 1 à 32 lettres, chiffres, points ou tirets."
  }
}

variable "tags" {
  description = "EN: Tags for every resource (include Owner) / FR: Étiquettes de chaque ressource (avec Owner)"
  type        = map(string)

  validation {
    condition     = contains(keys(var.tags), "Owner")
    error_message = "EN: tags must include Owner. / FR : tags doit contenir Owner."
  }
}
