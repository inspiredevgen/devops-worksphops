# -----------------------------------------------------------------------------
# Lab 1.I-AWS — Reading plans like a pro: update, replace, -replace, -target, drift
# Lab 1.I-AWS — Lire un plan comme un pro : update, replace, -replace, -target, dérive
#
# EN: A small but realistic stack (bucket + settings + one object). You will
#     change ONE variable at a time and predict the plan BEFORE running it.
# FR: Une petite pile réaliste (compartiment + paramètres + un objet). Vous
#     changerez UNE variable à la fois et prédirez le plan AVANT de l'exécuter.
# -----------------------------------------------------------------------------

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "lab" {
  bucket        = "${var.bucket_prefix}-${random_id.suffix.hex}"
  force_destroy = true

  # EN: Merged with the provider's default_tags.
  # FR: Fusionnées avec les default_tags du provider.
  tags = {
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "lab" {
  bucket = aws_s3_bucket.lab.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "lab" {
  bucket = aws_s3_bucket.lab.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# EN: A small text object. Its content comes from a variable.
# FR: Un petit objet texte. Son contenu provient d'une variable.
resource "aws_s3_object" "readme" {
  bucket       = aws_s3_bucket.lab.id
  key          = "README.txt"
  content      = var.welcome_message
  content_type = "text/plain"
}
