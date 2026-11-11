# =============================================================================
# Lab 10.A-AWS — A small stack to PLAN and GATE (you never need to apply it)
# Lab 10.A-AWS — Une petite pile à PLANIFIER et FILTRER (inutile de l'appliquer)
# =============================================================================

data "aws_vpc" "default" {
  default = true
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "app" {
  name        = "tf-lab-m10-gate-app"
  description = "App tier"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTPS from the private network"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  dynamic "ingress" {
    for_each = var.ssh_from_anywhere ? [1] : []
    content {
      description = "SSH from anywhere (BAD)"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    description = "HTTPS out"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ssm_parameter.al2023.insecure_value
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.app.id]

  metadata_options {
    http_tokens = var.require_imdsv2 ? "required" : "optional"
  }

  root_block_device {
    encrypted = true
  }
}

resource "aws_s3_bucket" "data" {
  bucket_prefix = "tf-lab-m10-gate-"
}
