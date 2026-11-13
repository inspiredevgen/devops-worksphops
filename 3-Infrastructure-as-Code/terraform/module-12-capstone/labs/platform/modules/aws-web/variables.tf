variable "name" {
  description = "EN: Name prefix, e.g. tf-capstone-dev / FR: Préfixe de nom, ex. tf-capstone-dev"
  type        = string

  validation {
    condition     = can(regex("^tf-[a-z0-9-]{3,24}$", var.name))
    error_message = "EN: 3-24 lowercase letters, digits or hyphens after \"tf-\" (ALB and target group names are limited to 32 characters). / FR : 3 à 24 minuscules, chiffres ou tirets après « tf- » (noms d'ALB et de groupes cibles limités à 32 caractères)."
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

variable "vpc_cidr" {
  description = "EN: VPC address space (/16-/20); must not overlap any network you'll connect / FR: Espace d'adressage du VPC (/16-/20) ; sans chevauchement"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) >= 16 && tonumber(split("/", var.vpc_cidr)[1]) <= 20
    error_message = "EN: A valid /16 to /20. / FR : Un /16 à /20 valide."
  }
}

variable "az_count" {
  description = "EN: Availability Zones (2-3) / FR: Zones de disponibilité (2-3)"
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "EN: An ALB needs at least 2 AZs; at most 3. / FR : Un ALB exige au moins 2 AZ ; 3 au plus."
  }
}

variable "availability_zones" {
  description = "EN: Pin the AZs (recommended for prod); [] = the first az_count available / FR: Épingler les AZ (recommandé en prod) ; [] = les az_count premières disponibles"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.availability_zones) == 0 || length(var.availability_zones) >= 2
    error_message = "EN: Pin at least 2 AZs, or leave empty. / FR : Épinglez au moins 2 AZ, ou laissez vide."
  }
}

variable "nat_gateway_per_az" {
  description = "EN: true = one NAT per AZ (HA, prod); false = one shared NAT (cheaper, dev) / FR: true = une NAT par AZ (HA, prod) ; false = une NAT partagée (moins chère, dev)"
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "EN: EC2 instance type / FR: Type d'instance EC2"
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "EN: Minimum instances / FR: Instances minimum"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "EN: Maximum instances / FR: Instances maximum"
  type        = number
  default     = 2
}

variable "allowed_cidrs" {
  description = "EN: Who may reach the load balancer / FR: Qui peut joindre l'équilibreur de charge"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for c in var.allowed_cidrs : can(cidrhost(c, 0))])
    error_message = "EN: Every entry must be a valid CIDR. / FR : Chaque entrée doit être un CIDR valide."
  }
}

variable "certificate_arn" {
  description = "EN: Optional ACM certificate; enables HTTPS + redirect / FR: Certificat ACM facultatif ; active HTTPS + redirection"
  type        = string
  default     = null
}

variable "app_version" {
  description = "EN: Shown on the page; changing it rolls the fleet with zero downtime / FR: Affiché sur la page ; le changer renouvelle la flotte sans interruption"
  type        = string
  default     = "1.0.0"

  # EN: The version ends up in a shell command and a sed expression: allow only safe characters.
  # FR : La version finit dans une commande shell et une expression sed : seuls des caractères sûrs.
  validation {
    condition     = can(regex("^[0-9A-Za-z.-]{1,32}$", var.app_version))
    error_message = "EN: 1-32 letters, digits, dots or hyphens. / FR : 1 à 32 lettres, chiffres, points ou tirets."
  }
}
