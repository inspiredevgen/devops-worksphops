# Run ONCE per team, with LOCAL state, before anything else (Phase 0).
# Creates the S3 bucket that stores the DEV and PROD state files.
terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ca-central-1"
}

variable "team" {
  type = string
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "state" {
  bucket = "kivubrew-${var.team}-tfstate-${data.aws_caller_identity.current.account_id}"

  # Set to true at the very end of the course, then apply, then destroy.
  force_destroy = false

  tags = {
    Purpose = "terraform-state"
    Team    = var.team
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled" # lets us recover a corrupted state file
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket_name" {
  value = aws_s3_bucket.state.bucket
}
