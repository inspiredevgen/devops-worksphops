# =============================================================================
# Lab 8.B-AWS — A two-tier VPC planned with cidrsubnet()
# Lab 8.B-AWS — Un VPC à deux niveaux planifié avec cidrsubnet()
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "tf-lab-m08"
  azs  = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # EN: The address plan. /16 + 8 new bits = /24 subnets.
  #     Public: netnum 0, 1, 2 → 10.80.0.0/24, 10.80.1.0/24, …
  #     Private: netnum 10, 11, 12 → 10.80.10.0/24, 10.80.11.0/24, …
  # FR : Le plan d'adressage. /16 + 8 bits = sous-réseaux /24.
  #     Publics : netnum 0, 1, 2 → 10.80.0.0/24, 10.80.1.0/24, …
  #     Privés : netnum 10, 11, 12 → 10.80.10.0/24, 10.80.11.0/24, …
  public_cidrs  = { for i, az in local.azs : az => cidrsubnet(var.vpc_cidr, 8, i) }
  private_cidrs = { for i, az in local.azs : az => cidrsubnet(var.vpc_cidr, 8, i + 10) }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name}-vpc" }
}

# EN: Best practice: strip all rules from the default security group so nothing uses it by accident.
# FR : Bonne pratique : retirer toutes les règles du groupe de sécurité par défaut pour que rien ne l'utilise par erreur.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-default-locked" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-igw" }
}

# ---------------------------------------------------------------- Public tier
resource "aws_subnet" "public" {
  for_each = local.public_cidrs

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = { Name = "${local.name}-public-${each.key}", Tier = "public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-public-rt" }
}

# EN: "Public" means exactly this: a route to an internet gateway.
# FR : « Public » signifie exactement ceci : une route vers une passerelle Internet.
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

# --------------------------------------------------------------- Private tier
resource "aws_subnet" "private" {
  for_each = local.private_cidrs

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = { Name = "${local.name}-private-${each.key}", Tier = "private" }
}

# EN: One route table per AZ, so each AZ could get its own NAT gateway later (high availability).
# FR : Une table de routage par AZ, pour que chaque AZ puisse plus tard avoir sa propre passerelle NAT (haute disponibilité).
resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-private-rt-${each.key}" }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# ------------------------------------------------- Optional NAT (cost: ~$0.05/h)
resource "aws_eip" "nat" {
  count  = var.enable_nat ? 1 : 0
  domain = "vpc"
  tags   = { Name = "${local.name}-nat-eip" }
}

# EN: ONE NAT gateway in the first public subnet: cheap, but not highly available.
# FR : UNE passerelle NAT dans le premier sous-réseau public : économique, mais pas hautement disponible.
resource "aws_nat_gateway" "this" {
  count = var.enable_nat ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[local.azs[0]].id
  tags          = { Name = "${local.name}-nat" }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route" "private_nat" {
  for_each = var.enable_nat ? aws_route_table.private : {}

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

# -------------------------------------------------------------------- Outputs
output "vpc_id" {
  value = aws_vpc.this.id
}

output "address_plan" {
  description = "EN: Subnet CIDRs per tier and AZ / FR: CIDR des sous-réseaux par niveau et par AZ"
  value = {
    public  = local.public_cidrs
    private = local.private_cidrs
  }
}

output "free_addresses_per_subnet" {
  description = "EN: AWS reserves 5 IPs per subnet / FR: AWS réserve 5 IP par sous-réseau"
  value       = pow(2, 32 - tonumber(split("/", cidrsubnet(var.vpc_cidr, 8, 0))[1])) - 5
}
