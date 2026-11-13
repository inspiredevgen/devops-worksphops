# =============================================================================
# Lab 10.B-AZ, part 2 — SEALED: ephemeral values + write-only arguments (Terraform ≥ 1.11)
# Lab 10.B-AZ, partie 2 — SCELLÉ : valeurs éphémères + arguments en écriture seule (Terraform ≥ 1.11)
# =============================================================================

variable "api_token" {
  description = "EN: Third-party API token (export TF_VAR_api_token=…) / FR: Jeton d'API tiers (export TF_VAR_api_token=…)"
  type        = string
  sensitive   = true
  ephemeral   = true # ✅ never written to state or plan files / jamais écrit dans l'état ni les plans
}

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

# ✅ EN: Ephemeral resource: generated during the run, never stored. / FR : Ressource éphémère : générée pendant l'exécution, jamais stockée.
ephemeral "random_password" "db" {
  length           = 24
  override_special = "!#%*-_=+"
}

resource "azurerm_key_vault_secret" "db" {
  name             = "db-password"
  value_wo         = ephemeral.random_password.db.result # ✅ write-only / écriture seule
  value_wo_version = var.db_password_version
  key_vault_id     = azurerm_key_vault.this.id
}

resource "azurerm_key_vault_secret" "api" {
  name             = "api-token"
  value_wo         = var.api_token
  value_wo_version = var.api_token_version
  key_vault_id     = azurerm_key_vault.this.id
}

# EN: Hand out pointers (IDs, URIs), never values. / FR : Transmettez des pointeurs (ID, URI), jamais des valeurs.
output "secret_ids" {
  value = {
    db  = azurerm_key_vault_secret.db.versionless_id
    api = azurerm_key_vault_secret.api.versionless_id
  }
}

output "vault_name" {
  value = azurerm_key_vault.this.name
}
