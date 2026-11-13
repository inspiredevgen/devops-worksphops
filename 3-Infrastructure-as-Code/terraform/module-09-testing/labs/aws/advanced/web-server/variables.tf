variable "name" {
  description = "EN: Name prefix (tf-…) / FR: Préfixe de nom (tf-…)"
  type        = string

  validation {
    condition     = can(regex("^tf-[a-z0-9-]{3,40}$", var.name))
    error_message = "EN: Lowercase, digits and hyphens, starting with \"tf-\". / FR : Minuscules, chiffres et tirets, commençant par « tf- »."
  }
}

variable "allowed_cidr" {
  description = "EN: Who may reach port 80 (never 0.0.0.0/0) / FR: Qui peut joindre le port 80 (jamais 0.0.0.0/0)"
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_cidr, 0)) && var.allowed_cidr != "0.0.0.0/0"
    error_message = "EN: A valid CIDR, and not the whole internet. / FR : Un CIDR valide, et pas tout Internet."
  }
}

variable "message" {
  description = "EN: Text shown on the page / FR: Texte affiché sur la page"
  type        = string
  default     = "Hello from a tested module! / Bonjour depuis un module testé !"
}

variable "instance_type" {
  description = "EN: EC2 instance type / FR: Type d'instance EC2"
  type        = string
  default     = "t3.micro"
}
