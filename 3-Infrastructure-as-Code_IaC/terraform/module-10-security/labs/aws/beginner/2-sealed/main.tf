# =============================================================================
# Lab 10.B-AWS, part 2 — SEALED: ephemeral values + write-only arguments (Terraform ≥ 1.11)
# Lab 10.B-AWS, partie 2 — SCELLÉ : valeurs éphémères + arguments en écriture seule (Terraform ≥ 1.11)
# EN: The secrets reach AWS, but never Terraform's state or plan files.
# FR : Les secrets arrivent dans AWS, mais jamais dans l'état ni dans les plans de Terraform.
# =============================================================================

terraform {
  required_version = ">= 1.11.0, < 2.0.0" # EN: write-only arguments / FR : arguments en écriture seule

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7" # EN: ephemeral random_password / FR : random_password éphémère
    }
  }
}

provider "aws" {
  region = "ca-central-1"

  default_tags {
    tags = {
      Course    = "terraform-cloud-engineer"
      Module    = "10-security"
      ManagedBy = "terraform"
    }
  }
}

# ✅ EN: ephemeral = true: allowed only in ephemeral contexts (write-only args, providers…), never saved.
# ✅ FR : ephemeral = true : autorisé seulement dans des contextes éphémères (arguments en écriture seule, providers…), jamais enregistré.
variable "api_token" {
  description = "EN: Third-party API token (export TF_VAR_api_token=…) / FR: Jeton d'API tiers (export TF_VAR_api_token=…)"
  type        = string
  sensitive   = true
  ephemeral   = true
}

# EN: Write-only values aren't in state, so Terraform can't diff them. Bump a VERSION to push a new value.
# FR : Les valeurs en écriture seule ne sont pas dans l'état : Terraform ne peut pas les comparer. Incrémentez une VERSION pour envoyer une nouvelle valeur.
variable "db_password_version" {
  description = "EN: Increment to rotate the DB password / FR: Incrémenter pour renouveler le mot de passe"
  type        = number
  default     = 1
}

variable "api_token_version" {
  description = "EN: Increment after changing TF_VAR_api_token / FR: Incrémenter après avoir changé TF_VAR_api_token"
  type        = number
  default     = 1
}

resource "random_id" "suffix" {
  byte_length = 3
}

# ✅ EN: An EPHEMERAL resource: generated during the run, never stored.
# ✅ FR : Une ressource ÉPHÉMÈRE : générée pendant l'exécution, jamais stockée.
ephemeral "random_password" "db" {
  length           = 24
  override_special = "!#%*-_=+"
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "tf-lab-m10-sealed-db-${random_id.suffix.hex}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id                = aws_secretsmanager_secret.db.id
  secret_string_wo         = ephemeral.random_password.db.result # ✅ write-only / écriture seule
  secret_string_wo_version = var.db_password_version
}

resource "aws_secretsmanager_secret" "api" {
  name                    = "tf-lab-m10-sealed-api-${random_id.suffix.hex}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "api" {
  secret_id                = aws_secretsmanager_secret.api.id
  secret_string_wo         = var.api_token
  secret_string_wo_version = var.api_token_version
}

# EN: Hand out a POINTER to the secret, never the secret. Apps read it at runtime with IAM.
# FR : Transmettez un POINTEUR vers le secret, jamais le secret. Les applications le lisent à l'exécution via IAM.
output "secret_arns" {
  value = {
    db  = aws_secretsmanager_secret.db.arn
    api = aws_secretsmanager_secret.api.arn
  }
}
