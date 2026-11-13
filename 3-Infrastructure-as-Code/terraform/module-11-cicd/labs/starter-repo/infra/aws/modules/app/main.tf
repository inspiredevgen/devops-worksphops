# =============================================================================
# The small app deployed by the pipeline: a private bucket + a configuration parameter.
# La petite application déployée par le pipeline : un compartiment privé + un paramètre de configuration.
# EN: Names start with tf-cicd-<environment>-: the ONLY names the apply role may touch.
# FR : Les noms commencent par tf-cicd-<environment>- : les SEULS que le rôle apply peut toucher.
# =============================================================================

resource "random_id" "suffix" {
  byte_length = 3
}

resource "aws_s3_bucket" "this" {
  bucket = "tf-cicd-${var.environment}-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_ssm_parameter" "message" {
  name  = "/tf-cicd/${var.environment}/message"
  type  = "String"
  value = var.message
}
