# =============================================================================
# Reusable network module / Module réseau réutilisable
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # EN: Same plan as Lab 8.B, scaled to the VPC size: +4 bits for /16 → /20 subnets.
  # FR : Même plan qu'au lab 8.B, adapté à la taille du VPC : +4 bits pour /16 → sous-réseaux /20.
  newbits = 24 - tonumber(split("/", var.cidr)[1]) > 4 ? 4 : 24 - tonumber(split("/", var.cidr)[1])

  public  = var.public_subnets ? { for i, az in local.azs : tostring(i) => { az = az, cidr = cidrsubnet(var.cidr, local.newbits, i) } } : {}
  private = { for i, az in local.azs : tostring(i) => { az = az, cidr = cidrsubnet(var.cidr, local.newbits, i + 8) } }
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.name}-vpc" }
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-default-locked" }
}

resource "aws_internet_gateway" "this" {
  count  = var.public_subnets ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-igw" }
}

resource "aws_subnet" "public" {
  for_each = local.public

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value.az
  cidr_block        = each.value.cidr
  tags              = { Name = "${var.name}-public-${each.value.az}", Tier = "public" }
}

resource "aws_route_table" "public" {
  count  = var.public_subnets ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-public-rt" }
}

resource "aws_route" "public_internet" {
  count = var.public_subnets ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_subnet" "private" {
  for_each = local.private

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value.az
  cidr_block        = each.value.cidr
  tags              = { Name = "${var.name}-private-${each.value.az}", Tier = "private" }
}

resource "aws_route_table" "private" {
  for_each = local.private

  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-private-rt-${each.value.az}" }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# EN: Gateway endpoints for S3 are FREE: private subnets reach S3 without a NAT gateway.
# FR : Les points de terminaison passerelle S3 sont GRATUITS : les sous-réseaux privés joignent S3 sans NAT.
resource "aws_vpc_endpoint" "s3" {
  count = var.s3_gateway_endpoint ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.private : rt.id]
  tags              = { Name = "${var.name}-s3-endpoint" }
}
