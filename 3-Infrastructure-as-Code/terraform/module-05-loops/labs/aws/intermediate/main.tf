# -----------------------------------------------------------------------------
# Lab 5.I-AWS — for_each over maps, filters, grouping and flatten
# Lab 5.I-AWS — for_each sur des maps, filtres, regroupements et flatten
#
# EN: Cost: $0 (VPC, subnets, IGW, route tables, IAM roles are free).
# FR: Coût : 0 $ (VPC, sous-réseaux, IGW, tables de routage, rôles IAM gratuits).
# -----------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags                 = { Name = "vpc-tf-lab-m05" }
}

# EN: for_each over a MAP → each.key = "web-a", each.value = { netnum, az_index, public }
#     Address: aws_subnet.this["web-a"]
# FR: for_each sur une MAP → each.key = « web-a », each.value = { netnum, az_index, public }
#     Adresse : aws_subnet.this["web-a"]
resource "aws_subnet" "this" {
  for_each = var.subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value.netnum)
  availability_zone       = local.azs[each.value.az_index]
  map_public_ip_on_launch = each.value.public

  tags = {
    Name = "snet-tf-lab-m05-${each.key}"
    Tier = split("-", each.key)[0]
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "igw-tf-lab-m05" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "rt-tf-lab-m05-public" }
}

# EN: for_each over a SET of strings (the filtered keys) → each.key == each.value.
# FR: for_each sur un ENSEMBLE de chaînes (les clés filtrées) → each.key == each.value.
resource "aws_route_table_association" "public" {
  for_each = local.public_subnet_keys

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# EN: IAM roles per team (for_each over a map of objects).
# FR: Rôles IAM par équipe (for_each sur une map d'objets).
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "trust_account" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_iam_role" "team" {
  for_each = var.teams

  name               = "tf-lab-m05-team-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.trust_account.json

  tags = {
    Team   = each.key
    Access = each.value.access
  }
}

# EN: for_each needs a MAP (or set) → convert the flattened LIST into a map
#     keyed by the unique "team/policy" string.
# FR: for_each exige une MAP (ou un ensemble) → convertir la LISTE aplatie en
#     map indexée par la chaîne unique « équipe/politique ».
resource "aws_iam_role_policy_attachment" "team" {
  for_each = { for a in local.team_policy_attachments : a.key => a }

  role       = aws_iam_role.team[each.value.team].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.value.policy}"
}
