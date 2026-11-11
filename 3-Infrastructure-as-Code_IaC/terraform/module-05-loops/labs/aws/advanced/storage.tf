# -----------------------------------------------------------------------------
# Lab 5.A-AWS (part 2) — Nested and optional dynamic blocks
# Lab 5.A-AWS (partie 2) — Blocs dynamic imbriqués et optionnels
#
# EN: `dynamic` generates REPEATED NESTED BLOCKS inside ONE resource.
#     Use it when the API models a list as blocks (rules, transitions…).
#     Cost: $0 (empty bucket).
# FR: `dynamic` génère des BLOCS IMBRIQUÉS RÉPÉTÉS à l'intérieur d'UNE ressource.
#     À utiliser quand l'API modélise une liste en blocs (règles, transitions…).
#     Coût : 0 $ (compartiment vide).
# -----------------------------------------------------------------------------

resource "random_id" "suffix" {
  byte_length = 3
}

resource "aws_s3_bucket" "data" {
  bucket        = "tf-lab-m05-data-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  # EN: One `rule` block per element. `iterator = lc` renames the loop
  #     variable (default would be `rule`) — clearer when blocks are nested.
  # FR: Un bloc `rule` par élément. `iterator = lc` renomme la variable de
  #     boucle (par défaut `rule`) — plus clair quand les blocs sont imbriqués.
  dynamic "rule" {
    for_each = var.lifecycle_rules
    iterator = lc

    content {
      id     = lc.value.id
      status = "Enabled"

      filter {
        prefix = lc.value.prefix
      }

      # EN: NESTED dynamic: 0..N transition blocks per rule.
      # FR: dynamic IMBRIQUÉ : 0 à N blocs transition par règle.
      dynamic "transition" {
        for_each = lc.value.transitions

        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      # EN: OPTIONAL block idiom: for_each over [] (absent) or [value] (present).
      # FR: Idiome de bloc OPTIONNEL : for_each sur [] (absent) ou [valeur] (présent).
      dynamic "expiration" {
        for_each = lc.value.expire_days == null ? [] : [lc.value.expire_days]

        content {
          days = expiration.value
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = lc.value.noncurrent_expire_days == null ? [] : [lc.value.noncurrent_expire_days]

        content {
          noncurrent_days = noncurrent_version_expiration.value
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.data]
}
