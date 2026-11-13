# =============================================================================
# Lab 10.B-AWS, part 1 — THE LEAK: secrets that end up in plaintext in the state file
# Lab 10.B-AWS, partie 1 — LA FUITE : des secrets qui finissent en clair dans le fichier d'état
# EN: `sensitive = true` only hides values from CLI OUTPUT. It does NOT keep them out of state.
# FR : `sensitive = true` masque seulement les valeurs dans l'AFFICHAGE. Il ne les retire PAS de l'état.
# =============================================================================

terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
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

# EN: A human-provided secret. Pass it with: export TF_VAR_api_token=…
# FR : Un secret fourni par un humain. Passez-le avec : export TF_VAR_api_token=…
variable "api_token" {
  description = "EN: Third-party API token / FR: Jeton d'API tiers"
  type        = string
  sensitive   = true
}

resource "random_id" "suffix" {
  byte_length = 3
}

# ❌ EN: A MANAGED resource: its result is stored in state, forever.
# ❌ FR : Une ressource GÉRÉE : son résultat est stocké dans l'état, pour toujours.
resource "random_password" "db" {
  length           = 24
  override_special = "!#%*-_=+"
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "tf-lab-m10-leaky-db-${random_id.suffix.hex}"
  recovery_window_in_days = 0 # EN: lab only: delete immediately / FR : lab seulement : suppression immédiate
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id     = aws_secretsmanager_secret.db.id
  secret_string = random_password.db.result # ❌ stored in state / stocké dans l'état
}

resource "aws_secretsmanager_secret" "api" {
  name                    = "tf-lab-m10-leaky-api-${random_id.suffix.hex}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "api" {
  secret_id     = aws_secretsmanager_secret.api.id
  secret_string = var.api_token # ❌ stored in state AND in saved plan files / stocké dans l'état ET dans les plans enregistrés
}

output "db_password" {
  value     = random_password.db.result
  sensitive = true # EN: hidden in `terraform output`… but `-raw` and the state still reveal it
}

output "secret_names" {
  value = [aws_secretsmanager_secret.db.name, aws_secretsmanager_secret.api.name]
}
