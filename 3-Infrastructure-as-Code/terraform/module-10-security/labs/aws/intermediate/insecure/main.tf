# =============================================================================
# Lab 10.I-AWS — INSECURE ON PURPOSE. Scan it, never apply it.
# Lab 10.I-AWS — NON SÉCURISÉ EXPRÈS. Scannez-le, ne l'appliquez jamais.
# EN: Every problem here is common in real repositories. How many can you spot before scanning?
# FR : Chaque problème ici est courant dans de vrais dépôts. Combien en repérez-vous avant le scan ?
# =============================================================================

terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# EN: These are AWS's documentation EXAMPLE keys (not real), so scanners and secret detectors trigger.
# FR : Ce sont les clés d'EXEMPLE de la documentation AWS (pas réelles), pour déclencher les scanners.
provider "aws" {
  region     = "ca-central-1"
  access_key = "AKIAIOSFODNN7EXAMPLE"
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}

resource "aws_s3_bucket" "data" {
  bucket = "tf-lab-m10-insecure-data"
}

resource "aws_s3_bucket_ownership_controls" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_acl" "data" {
  bucket     = aws_s3_bucket.data.id
  acl        = "public-read"
  depends_on = [aws_s3_bucket_ownership_controls.data]
}

resource "aws_security_group" "app" {
  name        = "tf-lab-m10-insecure-app"
  description = "app"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app" {
  ami                         = "ami-0123456789abcdef0"
  instance_type               = "t3.micro"
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = true

  user_data = <<-EOT
    #!/bin/bash
    export DB_PASSWORD="SuperSecret123!"
    echo "starting app"
  EOT
}

resource "aws_iam_policy" "app" {
  name = "tf-lab-m10-insecure-app"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "*"
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "app" {
  name = "/tf-lab/m10/insecure"
}
