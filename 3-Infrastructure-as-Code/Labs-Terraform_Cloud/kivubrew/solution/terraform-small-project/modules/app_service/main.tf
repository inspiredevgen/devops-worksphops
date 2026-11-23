# Latest Amazon Linux 2023 AMI, resolved per region through a public SSM parameter.
# Because DEV and PROD run in different regions, a hard-coded AMI ID would break one of them.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---------- Security group: HTTP from the internet, SSH ONLY from the bastion ----------
resource "aws_security_group" "web" {
  name_prefix = "${var.name_prefix}-web-"
  description = "HTTP access to ${var.name_prefix} web server"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-web-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  for_each = toset(var.allowed_http_cidrs)

  security_group_id = aws_security_group.web.id
  description       = "HTTP from ${each.value}"
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ssh_from_bastion" {
  security_group_id            = aws_security_group.web.id
  description                  = "SSH from bastion host only"
  referenced_security_group_id = var.bastion_security_group_id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  description       = "All outbound (dnf, git clone)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------- The web server ----------
resource "aws_instance" "web" {
  ami                         = data.aws_ssm_parameter.al2023.insecure_value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    app_repo_url   = var.app_repo_url
    app_version    = var.app_version
    app_source_dir = var.app_source_dir
    environment    = var.environment
    aws_region     = var.aws_region
  })

  # Changing app_version changes user_data -> Terraform replaces the instance.
  # That replacement IS our deployment mechanism.
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  root_block_device {
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name       = "${var.name_prefix}-web"
    AppVersion = var.app_version
  }

  # A new AMI release must not silently replace PROD on the next plan.
  lifecycle {
    ignore_changes = [ami]
  }
}

# ---------- Optional stable public IP (used in PROD, since there is no DNS) ----------
resource "aws_eip" "web" {
  count = var.enable_eip ? 1 : 0

  domain   = "vpc"
  instance = aws_instance.web.id

  tags = {
    Name = "${var.name_prefix}-eip"
  }
}

locals {
  public_ip = var.enable_eip ? aws_eip.web[0].public_ip : aws_instance.web.public_ip
}
