variable "name" {
  description = "EN: Name suffix / FR: Suffixe de nom"
  type        = string
}

variable "location" {
  description = "EN: Azure region; on Azure, region is a RESOURCE argument / FR: Région Azure ; sur Azure, la région est un argument de RESSOURCE"
  type        = string
}

variable "cidr" {
  description = "EN: VNet CIDR / FR: CIDR du VNet"
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr, 0)) && tonumber(split("/", var.cidr)[1]) <= 20
    error_message = "EN: A valid CIDR of /20 or larger. / FR : Un CIDR valide de /20 ou plus grand."
  }
}

variable "subnets" {
  description = "EN: Subnet name → netnum (+8 bits) / FR: Nom du sous-réseau → netnum (+8 bits)"
  type        = map(number)
  default = {
    workload = 1
    data     = 2
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
