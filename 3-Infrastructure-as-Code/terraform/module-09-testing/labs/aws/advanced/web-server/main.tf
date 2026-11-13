# =============================================================================
# web-server: the Module 7 web server, now a module with unit AND integration tests
# web-server : le serveur web du module 7, devenu un module avec tests unitaires ET d'intégration
# =============================================================================

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# EN: AWS publishes the latest Amazon Linux 2023 AMI ID in a public SSM parameter.
# FR : AWS publie l'ID de la dernière AMI Amazon Linux 2023 dans un paramètre SSM public.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    title   = var.name
    message = var.message
  })
}

resource "aws_security_group" "this" {
  name        = "${var.name}-web"
  description = "HTTP from allowed_cidr only"
  vpc_id      = data.aws_vpc.default.id
  tags        = { Name = "${var.name}-web" }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.this.id
  description       = "HTTP from the allowed CIDR"
  cidr_ipv4         = var.allowed_cidr
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "Package downloads"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "this" {
  # EN: An ACCEPTED risk, documented where it lives. Checkov reads this comment and skips the check.
  # FR : Un risque ACCEPTÉ, documenté là où il se trouve. Checkov lit ce commentaire et ignore la vérification.
  #checkov:skip=CKV_AWS_88:Public web server by design for this lab; port 80 is limited to allowed_cidr.
  ami                         = data.aws_ssm_parameter.al2023.insecure_value
  instance_type               = var.instance_type
  subnet_id                   = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids      = [aws_security_group.this.id]
  associate_public_ip_address = true
  monitoring                  = true

  user_data                   = local.user_data
  user_data_replace_on_change = true

  metadata_options {
    http_tokens   = "required" # EN: IMDSv2 only / FR : IMDSv2 seulement
    http_endpoint = "enabled"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = { Name = "${var.name}-web" }
}
