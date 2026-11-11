variable "aws_region" {
  type    = string
  default = "ca-central-1"
}

# EN: "shared" is the hub (shared services). Every other key is a spoke.
# FR : « shared » est le hub (services partagés). Toutes les autres clés sont des rayons (spokes).
variable "vpcs" {
  description = "EN: VPC name → CIDR / FR: Nom du VPC → CIDR"
  type        = map(string)
  default = {
    shared = "10.90.0.0/16"
    app    = "10.91.0.0/16"
    data   = "10.92.0.0/16"
  }

  validation {
    condition     = contains(keys(var.vpcs), "shared") && length(var.vpcs) >= 3
    error_message = "EN: Need a \"shared\" VPC plus at least two spokes. / FR : Il faut un VPC « shared » et au moins deux rayons."
  }
}

# EN: One summary route in every VPC instead of one route per peer network.
# FR : Une seule route de synthèse dans chaque VPC au lieu d'une route par réseau pair.
variable "supernet" {
  description = "EN: Summary CIDR covering all VPCs / FR: CIDR de synthèse couvrant tous les VPC"
  type        = string
  default     = "10.0.0.0/8"
}

variable "private_zone" {
  description = "EN: Private DNS zone shared by all VPCs / FR: Zone DNS privée partagée par tous les VPC"
  type        = string
  default     = "lab.internal"
}
