# -----------------------------------------------------------------------------
# EN: A small, opinionated module: a private, encrypted bucket that can
#     optionally be locked to a VPC endpoint (data plane only — Terraform can
#     still manage the bucket from your laptop).
# FR: Un petit module opiniâtre : un compartiment privé et chiffré, qui peut
#     être limité à un point de terminaison VPC (plan de données seulement —
#     Terraform peut toujours gérer le compartiment depuis votre portable).
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "this" {
  bucket        = "${var.name_prefix}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # EN: lab only / FR: lab uniquement
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "vpce_only" {
  count = var.restrict_to_vpc_endpoint ? 1 : 0

  statement {
    sid       = "DenyObjectAccessOutsideVpcEndpoint"
    effect    = "Deny"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceVpce"
      values   = [coalesce(var.vpc_endpoint_id, "missing")]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  count = var.restrict_to_vpc_endpoint ? 1 : 0

  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.vpce_only[0].json

  # EN: Fail fast with a clear message (preconditions → Module 9).
  # FR: Échouer vite avec un message clair (préconditions → module 9).
  lifecycle {
    precondition {
      condition     = var.vpc_endpoint_id != null
      error_message = "EN: vpc_endpoint_id is required when restrict_to_vpc_endpoint = true. / FR : vpc_endpoint_id est requis quand restrict_to_vpc_endpoint = true."
    }
  }

  depends_on = [aws_s3_bucket_public_access_block.this]
}
