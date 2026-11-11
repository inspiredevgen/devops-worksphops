# -----------------------------------------------------------------------------
# EN: Network module: VPC + Internet Gateway + public and private subnets in
#     N AZs + route tables. No NAT gateway (cost). `for_each` creates one
#     subnet per AZ — a preview of Module 5.
#     Naming convention inside modules: use `this` (or `main`) when there is
#     only one resource of a type.
# FR: Module réseau : VPC + passerelle Internet + sous-réseaux publics et
#     privés dans N zones + tables de routage. Pas de NAT (coût). `for_each`
#     crée un sous-réseau par zone — un aperçu du module 5.
#     Convention de nommage dans les modules : `this` (ou `main`) quand il n'y
#     a qu'une ressource d'un type.
# -----------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(sort(data.aws_availability_zones.available.names), 0, var.az_count)

  # EN: +4 bits per subnet: public get netnums 0..2, private 8..10 (no overlap).
  # FR: +4 bits par sous-réseau : publics netnum 0..2, privés 8..10 (sans chevauchement).
  public_subnets  = { for i, az in local.azs : az => cidrsubnet(var.cidr_block, 4, i) }
  private_subnets = { for i, az in local.azs : az => cidrsubnet(var.cidr_block, 4, i + 8) }
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "vpc-${var.name}" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "igw-${var.name}" })
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = true

  tags = merge(var.tags, { Name = "snet-${var.name}-public-${each.key}", Tier = "public" })
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(var.tags, { Name = "snet-${var.name}-private-${each.key}", Tier = "private" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, { Name = "rt-${var.name}-public" })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# EN: Private subnets: local routes only (add a NAT route in real projects).
# FR: Sous-réseaux privés : routes locales uniquement (ajoutez une route NAT en vrai projet).
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "rt-${var.name}-private" })
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# EN: v1.1.0 — S3 gateway endpoint (free): S3 traffic stays on the AWS network.
#     `count = condition ? 1 : 0` is the classic "optional resource" pattern (Module 5).
# FR: v1.1.0 — point de terminaison passerelle S3 (gratuit) : le trafic S3 reste sur le réseau AWS.
#     `count = condition ? 1 : 0` est le patron classique de « ressource optionnelle » (module 5).
data "aws_region" "current" {}

resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_endpoint ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public.id, aws_route_table.private.id]

  tags = merge(var.tags, { Name = "vpce-${var.name}-s3" })
}
