# =============================================================================
# secure-bucket: an S3 bucket with four layers of guardrails
# secure-bucket : un compartiment S3 avec quatre couches de garde-fous
#   1. variable validation   (variables.tf)  → bad input
#   2. precondition          (below)         → bad COMBINATION of inputs / assumptions
#   3. postcondition         (below)         → the result is not what we promised
#   4. check block           (checks.tf)     → a wider fact worth a WARNING, never a failure
# =============================================================================

resource "aws_s3_bucket" "this" {
  bucket        = var.name
  force_destroy = var.force_destroy

  tags = { Environment = var.environment }

  lifecycle {
    # EN: Layer 2: each input is fine alone; the COMBINATION is forbidden.
    # FR : Couche 2 : chaque entrée est valide seule ; c'est la COMBINAISON qui est interdite.
    precondition {
      condition     = !(var.environment == "prod" && var.force_destroy)
      error_message = "EN: force_destroy is not allowed in prod. / FR : force_destroy est interdit en prod."
    }
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }

  lifecycle {
    # EN: Layer 3: verify the RESULT (after apply, with real values).
    # FR : Couche 3 : vérifier le RÉSULTAT (après l'apply, avec les vraies valeurs).
    postcondition {
      condition     = self.versioning_configuration[0].status == "Enabled"
      error_message = "EN: Versioning must be enabled. / FR : La gestion des versions doit être activée."
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_days
    }

    # EN: Clean up failed multipart uploads (found by Checkov CKV_AWS_300).
    # FR : Nettoyer les téléversements multipartie échoués (trouvé par Checkov CKV_AWS_300).
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}
