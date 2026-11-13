# -----------------------------------------------------------------------------
# Lab 3.I-AWS (part 1) — A production-grade S3 bucket for Terraform state
# Lab 3.I-AWS (partie 1) — Un compartiment S3 de qualité production pour l'état Terraform
#
# EN: Versioning (recovery), encryption, no public access, TLS-only, old
#     versions expired after N days, and prevent_destroy. Locking uses S3
#     native lock files (use_lockfile, Terraform ≥ 1.10) — no DynamoDB table.
#     Cost: a few cents per month at most.
# FR: Versionnage (récupération), chiffrement, aucun accès public, TLS
#     uniquement, expiration des anciennes versions après N jours, et
#     prevent_destroy. Le verrouillage utilise les fichiers de verrou natifs
#     de S3 (use_lockfile, Terraform ≥ 1.10) — sans table DynamoDB.
#     Coût : quelques cents par mois au maximum.
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

variable "noncurrent_version_days" {
  description = "EN: Days to keep old state versions / FR: Jours de conservation des anciennes versions d'état"
  type        = number
  default     = 90
}

data "aws_caller_identity" "current" {}

locals {
  bucket_name = "tfstate-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
}

resource "aws_s3_bucket" "state" {
  bucket = local.bucket_name

  # EN: Losing this bucket = losing track of ALL your infrastructure.
  # FR: Perdre ce compartiment = perdre la trace de TOUTE votre infrastructure.
  lifecycle {
    prevent_destroy = true
  }
}

# EN: Every state write creates a new version → you can roll back.
# FR: Chaque écriture d'état crée une nouvelle version → retour arrière possible.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # EN: KMS CMK in Module 10 / FR: CMK KMS au module 10
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # EN: Lifecycle rules on versioned buckets require versioning first.
  # FR: Les règles de cycle de vie sur un compartiment versionné exigent d'abord le versionnage.
  depends_on = [aws_s3_bucket_versioning.state]
}

# EN: Deny any request that is not over HTTPS.
# FR: Refuser toute requête qui n'utilise pas HTTPS.
data "aws_iam_policy_document" "tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.tls_only.json

  depends_on = [aws_s3_bucket_public_access_block.state]
}
