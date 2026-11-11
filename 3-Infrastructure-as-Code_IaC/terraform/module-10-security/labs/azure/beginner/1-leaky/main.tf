# =============================================================================
# Lab 10.B-AZ, part 1 — THE LEAK / Lab 10.B-AZ, partie 1 — LA FUITE
# EN: `sensitive = true` only hides values from CLI OUTPUT. It does NOT keep them out of state.
# FR : `sensitive = true` masque seulement les valeurs dans l'AFFICHAGE. Il ne les retire PAS de l'état.
# =============================================================================

variable "api_token" {
  description = "EN: Third-party API token (export TF_VAR_api_token=…) / FR: Jeton d'API tiers (export TF_VAR_api_token=…)"
  type        = string
  sensitive   = true
}

# ❌ EN: Managed resource: the result is stored in state. / FR : Ressource gérée : le résultat est stocké dans l'état.
resource "random_password" "db" {
  length           = 24
  override_special = "!#%*-_=+"
}

resource "azurerm_key_vault_secret" "db" {
  name         = "db-password"
  value        = random_password.db.result # ❌ stored in state / stocké dans l'état
  key_vault_id = azurerm_key_vault.this.id
}

resource "azurerm_key_vault_secret" "api" {
  name         = "api-token"
  value        = var.api_token # ❌ stored in state and saved plans / stocké dans l'état et les plans enregistrés
  key_vault_id = azurerm_key_vault.this.id
}

output "db_password" {
  value     = random_password.db.result
  sensitive = true
}

output "vault_name" {
  value = azurerm_key_vault.this.name
}
