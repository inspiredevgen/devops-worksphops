# =============================================================================
# Lab 8.I-AWS — One module, two regions, cross-region VPC peering
# Lab 8.I-AWS — Un module, deux régions, appairage VPC inter-régions
# =============================================================================

locals {
  # EN: Peered networks must NOT overlap. Terraform has no "overlaps()" function, so we
  #     turn each CIDR into an integer range and compare: [start, start + size).
  # FR : Les réseaux appairés ne doivent PAS se chevaucher. Terraform n'a pas de fonction
  #     « overlaps() » : on convertit chaque CIDR en plage d'entiers et on compare : [début, début + taille).
  ranges = {
    for k, c in { primary = var.primary_cidr, secondary = var.secondary_cidr } : k => {
      start               = sum([for i, octet in split(".", cidrhost(c, 0)) : tonumber(octet) * pow(256, 3 - i)])
      size                = pow(2, 32 - tonumber(split("/", c)[1]))
    }
  }
  cidrs_overlap = (
    local.ranges.primary.start < local.ranges.secondary.start + local.ranges.secondary.size &&
    local.ranges.secondary.start < local.ranges.primary.start + local.ranges.primary.size
  )
}

module "primary" {
  source = "./modules/network"

  name = "tf-lab-m08-primary"
  cidr = var.primary_cidr
  # EN: providers omitted → the module inherits the default "aws" provider.
  # FR : providers omis → le module hérite du provider « aws » par défaut.
}

module "secondary" {
  source = "./modules/network"

  name = "tf-lab-m08-secondary"
  cidr = var.secondary_cidr

  # EN: Inside the module, "aws" now means OUR aws.secondary (the other region).
  # FR : Dans le module, « aws » désigne maintenant NOTRE aws.secondary (l'autre région).
  providers = {
    aws = aws.secondary
  }
}

# ----------------------------------------------------- Requester (primary side)
resource "aws_vpc_peering_connection" "this" {
  vpc_id      = module.primary.vpc_id
  peer_vpc_id = module.secondary.vpc_id
  peer_region = var.secondary_region
  auto_accept = false # EN: impossible across regions / FR : impossible entre régions

  tags = { Name = "tf-lab-m08-primary-to-secondary", Side = "requester" }

  lifecycle {
    precondition {
      condition     = !local.cidrs_overlap
      error_message = "EN: ${var.primary_cidr} and ${var.secondary_cidr} overlap; peering would fail. / FR : ${var.primary_cidr} et ${var.secondary_cidr} se chevauchent ; l'appairage échouerait."
    }
  }
}

# ----------------------------------------------------- Accepter (secondary side)
resource "aws_vpc_peering_connection_accepter" "this" {
  provider = aws.secondary

  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
  auto_accept               = true

  tags = { Name = "tf-lab-m08-secondary-from-primary", Side = "accepter" }
}

# ------------------------------------------- Routes in BOTH directions, every table
resource "aws_route" "primary_to_secondary" {
  for_each = toset(module.primary.route_table_keys)

  route_table_id            = module.primary.route_table_ids[each.key]
  destination_cidr_block    = module.secondary.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id

  depends_on = [aws_vpc_peering_connection_accepter.this]
}

resource "aws_route" "secondary_to_primary" {
  provider = aws.secondary
  for_each = toset(module.secondary.route_table_keys)

  route_table_id            = module.secondary.route_table_ids[each.key]
  destination_cidr_block    = module.primary.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id

  depends_on = [aws_vpc_peering_connection_accepter.this]
}

# -------------------------------------------------------------------- Outputs
output "peering_id" {
  value = aws_vpc_peering_connection.this.id
}

output "networks" {
  value = {
    primary   = { region = module.primary.region, vpc = module.primary.vpc_id, cidr = module.primary.cidr }
    secondary = { region = module.secondary.region, vpc = module.secondary.vpc_id, cidr = module.secondary.cidr }
  }
}

output "check_peering" {
  value = "aws ec2 describe-vpc-peering-connections --region ${var.primary_region} --vpc-peering-connection-ids ${aws_vpc_peering_connection.this.id} --query 'VpcPeeringConnections[0].Status.Code' --output text"
}
