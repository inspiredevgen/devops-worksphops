variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

variable "module_tag" {
  description = "EN: Module tag, e.g. 00-setup / FR: Étiquette du module, ex. 00-setup"
  type        = string
  default     = "00-setup"
}

# EN: The hosts to create. The KEY is the inventory hostname; role and environment become tags AND groups.
# FR : Les hôtes à créer. La CLÉ est le nom d'hôte d'inventaire ; role et environment deviennent des étiquettes ET des groupes.
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
    condition     = alltrue([for h in values(var.hosts) : contains(["ubuntu", "al2023"], h.os)])
    error_message = "EN: os must be ubuntu or al2023. / FR : os doit valoir ubuntu ou al2023."
  }

  validation {
    condition     = alltrue(flatten([for h in values(var.hosts) : [for k in keys(h.tags) : can(regex("^[A-Za-z][A-Za-z0-9_.-]{0,62}$", k))]]))
    error_message = "EN: Extra tag keys: letters, digits, _ - . (no spaces or /: AWS IMDS tags need it). / FR : Clés : lettres, chiffres, _ - . (ni espaces ni /)."
  }

  validation {
    condition     = alltrue([for k in keys(var.hosts) : can(regex("^[a-z][a-z0-9_]{0,20}$", k))])
    error_message = "EN: Host names: lowercase letters, digits, underscores (valid Ansible names). / FR : Noms d'hôtes : minuscules, chiffres, soulignés."
  }
}

# EN: ssh       = public IP + port 22 from YOUR IP only.
#     proxyjump = hosts have NO public IP; one jump host (port 22 from your IP) relays SSH (Module 1).
#     ssm       = NO inbound port at all (Session Manager).
# FR : ssh       = IP publique + port 22 depuis VOTRE IP seulement.
#     proxyjump = les hôtes n'ont AUCUNE IP publique ; un hôte de rebond (port 22 depuis votre IP) relaie SSH (module 1).
#     ssm       = AUCUN port entrant (Session Manager).
variable "access" {
  description = "EN: ssh, proxyjump or ssm / FR: ssh, proxyjump ou ssm"
  type        = string
  default     = "ssh"

  validation {
    condition     = contains(["ssh", "proxyjump", "ssm"], var.access)
    error_message = "EN: access must be ssh, proxyjump or ssm. / FR : access doit valoir ssh, proxyjump ou ssm."
  }
}

variable "my_ip" {
  description = "EN: Your public IPv4 (ssh and proxyjump modes) / FR: Votre IPv4 publique (modes ssh et proxyjump)"
  type        = string
  default     = null

  validation {
    condition     = var.my_ip == null || can(cidrhost("${var.my_ip}/32", 0))
    error_message = "EN: A plain IPv4 address. / FR : Une adresse IPv4 simple."
  }
}

variable "ssh_public_key_path" {
  description = "EN: Your SSH public key (ssh mode) / FR: Votre clé SSH publique (mode ssh)"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "instance_type" {
  description = "EN: Instance type / FR: Type d'instance"
  type        = string
  default     = "t3.micro"
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
