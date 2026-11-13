# =============================================================================
# Network: public subnets (load balancer, NAT) + private subnets (instances), one pair per AZ.
# Réseau : sous-réseaux publics (équilibreur, NAT) + privés (instances), une paire par AZ.
# =============================================================================

# EN: Unpinned, a NEW zone that sorts first would shift every subnet (replacement!). Pin AZs in prod.
# FR : Sans épinglage, une NOUVELLE zone triée en premier décalerait chaque sous-réseau (remplacement !). Épinglez en prod.
data "aws_availability_zones" "available" {
  #checkov:skip=CKV_AWS_394:Callers pin zones with var.availability_zones (live/aws/prod does); the data source is only the dev fallback.
  state = "available"
}

data "aws_region" "current" {}

locals {
  azs     = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, var.az_count)
  public  = { for i, az in local.azs : az => cidrsubnet(var.vpc_cidr, 4, i) }
  private = { for i, az in local.azs : az => cidrsubnet(var.vpc_cidr, 4, i + 8) }
  # EN: Which NAT each private subnet uses. / FR : Quelle NAT chaque sous-réseau privé utilise.
  nat_azs    = var.nat_gateway_per_az ? local.azs : [local.azs[0]]
  nat_for_az = { for az in local.azs : az => var.nat_gateway_per_az ? az : local.azs[0] }
}

resource "aws_vpc" "this" {
  #checkov:skip=CKV2_AWS_11:Flow logs need an IAM role or a log bucket; a capstone stretch goal (the CI apply role cannot create IAM roles).
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.name}-vpc" }
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-default-locked" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-igw" }
}

resource "aws_subnet" "public" {
  for_each = local.public

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value
  tags              = { Name = "${var.name}-public-${each.key}", Tier = "public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-public" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private" {
  for_each = local.private

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value
  tags              = { Name = "${var.name}-private-${each.key}", Tier = "private" }
}

resource "aws_eip" "nat" {
  #checkov:skip=CKV2_AWS_19:False positive: these EIPs belong to NAT gateways, not EC2 instances.
  for_each = toset(local.nat_azs)

  domain = "vpc"
  tags   = { Name = "${var.name}-nat-${each.key}" }
}

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_azs)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id
  tags          = { Name = "${var.name}-nat-${each.key}" }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "private" {
  for_each = local.private

  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-private-${each.key}" }
}

resource "aws_route" "private_nat" {
  for_each = local.private

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[local.nat_for_az[each.key]].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# EN: Free S3 gateway endpoint: S3 traffic from private subnets skips the (paid) NAT.
# FR : Point de terminaison passerelle S3 gratuit : le trafic S3 des sous-réseaux privés évite la NAT (payante).
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.private : rt.id]
  tags              = { Name = "${var.name}-s3" }
}
