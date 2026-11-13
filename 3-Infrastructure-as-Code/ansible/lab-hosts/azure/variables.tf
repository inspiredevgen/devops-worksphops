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

variable "module_tag" {
  description = "EN: Module tag, e.g. 00-setup / FR: Étiquette du module, ex. 00-setup"
  type        = string
  default     = "00-setup"
}

variable "hosts" {
  description = "EN: name → {os, role, environment} / FR: nom → {os, role, environment}"
  type = map(object({
    os          = string
    role        = string
    environment = string
    # EN: Extra tags (Module 3 builds configuration from them). Keys: letters, digits, _ - . only.
    # FR : Étiquettes supplémentaires (le module 3 construit de la configuration à partir d'elles).
    tags = optional(map(string), {})
  }))

  validation {
    condition     = alltrue([for h in values(var.hosts) : contains(["ubuntu", "almalinux"], h.os)])
    error_message = "EN: os must be ubuntu or almalinux. / FR : os doit valoir ubuntu ou almalinux."
  }

  validation {
    condition     = alltrue(flatten([for h in values(var.hosts) : [for k in keys(h.tags) : can(regex("^[A-Za-z][A-Za-z0-9_.-]{0,62}$", k))]]))
    error_message = "EN: Extra tag keys: letters, digits, _ - . (no spaces or /: AWS IMDS tags need it). / FR : Clés : lettres, chiffres, _ - . (ni espaces ni /)."
  }

  validation {
    condition     = alltrue([for k in keys(var.hosts) : can(regex("^[a-z][a-z0-9_]{0,20}$", k))])
    error_message = "EN: Host names: lowercase letters, digits, underscores. / FR : Noms d'hôtes : minuscules, chiffres, soulignés."
  }
}

# EN: ssh = one public IP per VM, port 22 from YOUR IP only. bastion = NO public IP on any VM;
#     you reach them through Azure Bastion tunnels on localhost (Standard SKU, about 20 cents/hour).
# FR : ssh = une IP publique par VM, port 22 depuis VOTRE IP seulement. bastion = AUCUNE IP publique ;
#     vous les joignez par des tunnels Azure Bastion sur localhost (SKU Standard, environ 20 cents/heure).
variable "access" {
  description = "EN: ssh or bastion / FR: ssh ou bastion"
  type        = string
  default     = "ssh"

  validation {
    condition     = contains(["ssh", "bastion"], var.access)
    error_message = "EN: access must be ssh or bastion. / FR : access doit valoir ssh ou bastion."
  }
}

variable "my_ip" {
  description = "EN: Your public IPv4 (ssh mode) / FR: Votre IPv4 publique (mode ssh)"
  type        = string
  default     = null

  validation {
    condition     = var.my_ip == null || can(cidrhost("${var.my_ip}/32", 0))
    error_message = "EN: A plain IPv4 address. / FR : Une adresse IPv4 simple."
  }
}

variable "ssh_public_key_path" {
  description = "EN: Your SSH public key / FR: Votre clé SSH publique"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "vm_size" {
  description = "EN: VM size / FR: Taille de VM"
  type        = string
  default     = "Standard_B1s"
}

# EN: Modules 0–3: Terraform writes a static inventory here. Module 4+: leave it null, the cloud API is the inventory.
# FR : Modules 0 à 3 : Terraform écrit un inventaire statique ici. Module 4+ : laissez null, l'API cloud est l'inventaire.
variable "inventory_path" {
  description = "EN: Where to write the Ansible inventory (absolute path), or null / FR: Où écrire l'inventaire Ansible (chemin absolu), ou null"
  type        = string
  default     = null

  validation {
    condition     = var.inventory_path == null || startswith(coalesce(var.inventory_path, "/"), "/")
    error_message = "EN: An absolute path, e.g. $(realpath …)/inventory.yml. / FR : Un chemin absolu."
  }
}

variable "tunnel_base_port" {
  description = "EN: bastion mode: first local port for tunnels / FR : mode bastion : premier port local des tunnels"
  type        = number
  default     = 50022
}

# EN: Extra TCP ports opened from YOUR IP only (ssh mode), e.g. [80] for the Module 2 web server.
# FR : Ports TCP supplémentaires ouverts depuis VOTRE IP seulement (mode ssh), ex. [80] pour le serveur web du module 2.
variable "open_ports" {
  description = "EN: Extra ports from my_ip / FR: Ports supplémentaires depuis my_ip"
  type        = list(number)
  default     = []

  validation {
    condition     = alltrue([for p in var.open_ports : p >= 1 && p <= 65535 && p != 22])
    error_message = "EN: Ports 1-65535, not 22 (already handled). / FR : Ports 1-65535, sauf 22 (déjà géré)."
  }
}

# EN: Module 5: put the hosts with role "web" behind a load balancer (HTTP 80, health check /healthz). ssh mode only.
# FR : Module 5 : placer les hôtes de rôle « web » derrière un équilibreur de charge (HTTP 80, contrôle /healthz). Mode ssh seulement.
variable "load_balancer" {
  description = "EN: Create a load balancer for the web hosts / FR: Créer un équilibreur pour les hôtes web"
  type        = bool
  default     = false
}

# EN: Module 7 (day-2): an autoscaled web tier (AWS Auto Scaling group / Azure VM Scale Set) of Ubuntu web servers.
#     Terraform creates it and IGNORES later capacity changes: scaling is a day-2 operation done by Ansible.
# FR : Module 7 (jour 2) : un tier web à mise à l'échelle automatique (ASG AWS / VMSS Azure) de serveurs web Ubuntu.
#     Terraform le crée et IGNORE les changements de capacité ultérieurs : la mise à l'échelle est faite par Ansible.
variable "scale_set" {
  description = "EN: null, or {capacity, max} / FR : null, ou {capacity, max}"
  type = object({
    capacity = number
    max      = optional(number, 4)
  })
  default = null

  validation {
    condition     = var.scale_set == null || (try(var.scale_set.capacity >= 0 && var.scale_set.capacity <= var.scale_set.max && var.scale_set.max <= 6, false))
    error_message = "EN: 0 <= capacity <= max <= 6. / FR : 0 <= capacity <= max <= 6."
  }
}
