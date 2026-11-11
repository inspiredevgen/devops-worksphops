# -----------------------------------------------------------------------------
# EN: app-stack — the SAME building block deployed in every environment.
#     Environments differ only by INPUTS, never by code.
# FR: app-stack — la MÊME brique déployée dans chaque environnement.
#     Les environnements ne diffèrent que par les ENTRÉES, jamais par le code.
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

locals {
  name = "${var.app_name}-${var.environment}"
  tags = merge(var.tags, { App = var.app_name, Environment = var.environment, DataClassification = var.data_classification })
}

resource "aws_s3_bucket" "data" {
  bucket        = "${local.name}-data-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.environment != "prod"
  tags          = local.tags
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id

  versioning_configuration {
    status = var.versioning ? "Enabled" : "Disabled"
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/tf-lab/m06/${local.name}"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

resource "aws_ssm_parameter" "config" {
  name = "/tf-lab/m06/${local.name}/config"
  type = "String"
  value = jsonencode(merge(var.settings, {
    environment = var.environment
    bucket      = aws_s3_bucket.data.bucket
    log_group   = aws_cloudwatch_log_group.app.name
  }))
  tags = local.tags
}

# EN: v1.1.0 — clean up incomplete multipart uploads (they cost money silently).
# FR: v1.1.0 — nettoyer les téléversements multipartie incomplets (ils coûtent en silence).
resource "aws_s3_bucket_lifecycle_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
