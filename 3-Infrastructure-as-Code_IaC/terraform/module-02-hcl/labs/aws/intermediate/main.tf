# -----------------------------------------------------------------------------
# Lab 2.I-AWS — One configuration, many environments
# Lab 2.I-AWS — Une configuration, plusieurs environnements
#
# EN: The same code produces different settings for dev and prod, driven by
#     *.tfvars files, locals and conditional expressions. Cost: ~$0
#     (empty bucket, empty log group, standard SSM parameters).
# FR: Le même code produit des paramètres différents pour dev et prod, grâce
#     aux fichiers *.tfvars, aux locals et aux expressions conditionnelles.
#     Coût : ~0 $ (compartiment vide, groupe de journaux vide, paramètres SSM standard).
# -----------------------------------------------------------------------------

# EN: Data sources: facts about the account we're deploying into.
# FR: Sources de données : informations sur le compte cible.
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# EN: Account ID in the name makes it globally unique without a random suffix.
# FR: L'ID de compte dans le nom le rend unique sans suffixe aléatoire.
resource "aws_s3_bucket" "artifacts" {
  bucket        = "${local.name_prefix}-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = !local.is_prod # EN: protect prod data / FR: protéger les données de prod
}

# EN: CONDITIONAL expression: condition ? value_if_true : value_if_false
# FR: Expression CONDITIONNELLE : condition ? valeur_si_vrai : valeur_si_faux
resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = local.settings.versioning ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-objects"
    status = "Enabled"

    filter {} # EN: applies to all objects / FR: s'applique à tous les objets

    expiration {
      days = local.settings.expiration_days
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/tf-lab/${local.name_prefix}/app"
  retention_in_days = local.settings.log_retention_days
}

# EN: jsonencode() turns an HCL object into a JSON string.
# FR: jsonencode() transforme un objet HCL en chaîne JSON.
resource "aws_ssm_parameter" "app_config" {
  name = "/tf-lab/${local.name_prefix}/config"
  type = "String"
  value = jsonencode({
    environment = var.environment
    region      = data.aws_region.current.region
    bucket      = aws_s3_bucket.artifacts.bucket
    log_group   = aws_cloudwatch_log_group.app.name
    debug       = !local.is_prod
  })
}

# EN: The sensitive variable is stored encrypted (SecureString, AWS-managed KMS key).
#     ⚠️ It is still written to the state file in plain text (see Module 10).
# FR: La variable sensible est stockée chiffrée (SecureString, clé KMS gérée par AWS).
#     ⚠️ Elle reste écrite en clair dans le fichier d'état (voir module 10).
resource "aws_ssm_parameter" "api_key" {
  name  = "/tf-lab/${local.name_prefix}/api-key"
  type  = "SecureString"
  value = var.api_key
}
