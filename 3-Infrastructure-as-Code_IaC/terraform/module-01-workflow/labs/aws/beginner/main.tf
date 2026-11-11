# -----------------------------------------------------------------------------
# Lab 1.B-AWS — Your first managed resource: a secure S3 bucket
# Lab 1.B-AWS — Votre première ressource gérée : un compartiment S3 sécurisé
#
# EN: Walk through the full workflow: init → fmt → validate → plan → apply →
#     inspect → destroy. Cost: ~$0 (empty bucket; S3 free tier).
# FR: Parcourez tout le cycle : init → fmt → validate → plan → apply →
#     inspection → destroy. Coût : ~0 $ (compartiment vide ; offre gratuite S3).
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

# EN: S3 bucket names are GLOBALLY unique across all AWS accounts, so we add
#     a random suffix. It is generated once and then stored in state.
# FR: Les noms de compartiments S3 sont UNIQUES À L'ÉCHELLE MONDIALE (tous comptes
#     AWS confondus) : nous ajoutons donc un suffixe aléatoire, généré une fois
#     puis conservé dans l'état.
resource "random_id" "suffix" {
  byte_length = 4 # EN: 8 hex characters / FR: 8 caractères hexadécimaux
}

# EN: The bucket. `force_destroy = true` lets `terraform destroy` delete it even
#     if it contains objects — convenient for labs, DANGEROUS in production.
# FR: Le compartiment. `force_destroy = true` permet à `terraform destroy` de le
#     supprimer même s'il contient des objets — pratique en lab, DANGEREUX en production.
resource "aws_s3_bucket" "lab" {
  bucket        = "tf-lab-m01-${random_id.suffix.hex}"
  force_destroy = true
}

# EN: Since AWS provider v4, bucket settings are SEPARATE resources that point
#     to the bucket. Terraform sees the reference and creates the bucket first
#     (implicit dependency).
# FR: Depuis la v4 du provider AWS, les paramètres du compartiment sont des
#     ressources SÉPARÉES qui pointent vers lui. Terraform voit la référence et
#     crée d'abord le compartiment (dépendance implicite).
resource "aws_s3_bucket_versioning" "lab" {
  bucket = aws_s3_bucket.lab.id

  versioning_configuration {
    status = "Enabled"
  }
}

# EN: Block every form of public access (best practice for all buckets).
# FR: Bloquer toute forme d'accès public (bonne pratique pour tout compartiment).
resource "aws_s3_bucket_public_access_block" "lab" {
  bucket = aws_s3_bucket.lab.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# EN: Encryption at rest with S3-managed keys (SSE-S3). AWS enables this by
#     default, but declaring it makes the intent explicit and reviewable.
# FR: Chiffrement au repos avec des clés gérées par S3 (SSE-S3). AWS l'active
#     par défaut, mais le déclarer rend l'intention explicite et révisable.
resource "aws_s3_bucket_server_side_encryption_configuration" "lab" {
  bucket = aws_s3_bucket.lab.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
