# -----------------------------------------------------------------------------
# Lab 3.A-AWS — Brownfield adoption: import, refactor, release
# Lab 3.A-AWS — Adoption de l'existant : importer, restructurer, libérer
#
# EN: STARTER FILE. These blocks describe resources that ALREADY EXIST
#     (created by scripts/setup.sh). Terraform will IMPORT them instead of
#     creating them. The security group has NO block on purpose: Terraform
#     will GENERATE it for you (step 2).
# FR: FICHIER DE DÉPART. Ces blocs décrivent des ressources qui EXISTENT DÉJÀ
#     (créées par scripts/setup.sh). Terraform va les IMPORTER au lieu de les
#     créer. Le groupe de sécurité n'a volontairement AUCUN bloc : Terraform
#     va le GÉNÉRER pour vous (étape 2).
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "legacy" {
  bucket = var.legacy_bucket_name

  # EN: Keep the existing tags; default_tags will add the course tags.
  # FR: Conserver les étiquettes existantes ; default_tags ajoutera celles du cours.
  tags = {
    Owner = "clickops"
    App   = "legacy"
  }
}

resource "aws_s3_bucket_versioning" "legacy" {
  bucket = aws_s3_bucket.legacy.id

  versioning_configuration {
    status = "Enabled"
  }
}

# EN: Step 4 renames this address to aws_ssm_parameter.app_config with `moved`.
# FR: L'étape 4 renomme cette adresse en aws_ssm_parameter.app_config avec `moved`.
resource "aws_ssm_parameter" "legacy" {
  name = "/tf-lab/m03/legacy-config"
  type = "String"
  value = jsonencode({
    log_level       = "info"
    max_connections = 50
  })
}
