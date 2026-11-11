# -----------------------------------------------------------------------------
# Lab 6.B-AWS — One configuration, several CLI workspaces
# Lab 6.B-AWS — Une configuration, plusieurs workspaces CLI
#
# EN: `terraform.workspace` = the name of the selected workspace. We use it to
#     pick settings and build names. Cost: $0 (empty bucket, SSM parameter).
# FR: `terraform.workspace` = le nom du workspace sélectionné. Nous l'utilisons
#     pour choisir les paramètres et construire les noms. Coût : 0 $.
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

data "aws_caller_identity" "current" {}

locals {
  # EN: Allowed workspaces and their settings. "default" is NOT allowed.
  # FR: Workspaces autorisés et leurs paramètres. « default » n'est PAS autorisé.
  env_settings = {
    dev = {
      versioning = "Disabled"
      log_level  = "debug"
    }
    prod = {
      versioning = "Enabled"
      log_level  = "warn"
    }
  }

  env = terraform.workspace

  # EN: lookup() with a fallback avoids a cryptic error; the guard below gives a clear one.
  # FR: lookup() avec repli évite une erreur obscure ; la garde ci-dessous en donne une claire.
  settings = lookup(local.env_settings, local.env, local.env_settings["dev"])
}

# EN: GUARD — fail the plan immediately in an unknown workspace (e.g. "default").
#     terraform_data is a built-in resource: no cloud object, just a place for
#     a precondition that runs before anything else is changed.
# FR: GARDE — faire échouer le plan immédiatement dans un workspace inconnu
#     (ex. « default »). terraform_data est une ressource intégrée : aucun objet
#     cloud, seulement un endroit pour une précondition évaluée avant tout changement.
resource "terraform_data" "workspace_guard" {
  input = local.env

  lifecycle {
    precondition {
      condition     = contains(keys(local.env_settings), local.env)
      error_message = "EN: Workspace '${local.env}' is not allowed. Run: terraform workspace select dev (or prod). / FR : Le workspace « ${local.env} » n'est pas autorisé. Lancez : terraform workspace select dev (ou prod)."
    }
  }
}

resource "aws_s3_bucket" "app" {
  bucket        = "tf-lab-m06-${local.env}-${data.aws_caller_identity.current.account_id}"
  force_destroy = local.env != "prod"

  depends_on = [terraform_data.workspace_guard]
}

resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id

  versioning_configuration {
    status = local.settings.versioning
  }
}

resource "aws_ssm_parameter" "config" {
  name = "/tf-lab/m06/${local.env}/config"
  type = "String"
  value = jsonencode({
    environment = local.env
    log_level   = local.settings.log_level
    bucket      = aws_s3_bucket.app.bucket
  })
}

output "workspace" {
  description = "EN: Current workspace / FR: Workspace actuel"
  value       = terraform.workspace
}

output "bucket_name" {
  description = "EN: Bucket for this workspace / FR: Compartiment de ce workspace"
  value       = aws_s3_bucket.app.bucket
}
