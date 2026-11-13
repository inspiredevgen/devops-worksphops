# -----------------------------------------------------------------------------
# Lab 2.A-AWS — Complex types, function chains and templatefile()
# Lab 2.A-AWS — Types complexes, chaînes de fonctions et templatefile()
#
# EN: A VPC with 2 subnets computed from functions, plus a configuration file
#     RENDERED from a template and stored in S3. Cost: ~$0 (VPCs, subnets and
#     an empty-ish bucket are free; no NAT gateway, no instances).
# FR: Un VPC avec 2 sous-réseaux calculés par des fonctions, et un fichier de
#     configuration GÉNÉRÉ depuis un modèle puis stocké dans S3. Coût : ~0 $
#     (VPC, sous-réseaux et petit compartiment gratuits ; ni NAT ni instance).
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "app" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-${local.name_prefix}"
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = local.subnet_cidrs["public"]
  availability_zone = local.azs[0]

  tags = {
    Name = "snet-${local.name_prefix}-public"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = local.subnet_cidrs["private"]
  availability_zone = local.azs[1]

  tags = {
    Name = "snet-${local.name_prefix}-private"
  }
}

resource "aws_s3_bucket" "config" {
  bucket        = "${local.name_prefix}-config-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket = aws_s3_bucket.config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# EN: The rendered template becomes an S3 object. Any change in variables,
#     defaults.yaml or the template shows up as a diff in the plan.
# FR: Le modèle généré devient un objet S3. Tout changement de variable, de
#     defaults.yaml ou du modèle apparaît comme une différence dans le plan.
resource "aws_s3_object" "app_config" {
  bucket       = aws_s3_bucket.config.id
  key          = "${var.app.environment}/app-config.yaml"
  content      = local.rendered_config
  content_type = "application/yaml"
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/tf-lab/${local.name_prefix}"
  retention_in_days = local.log_retention_days
}
