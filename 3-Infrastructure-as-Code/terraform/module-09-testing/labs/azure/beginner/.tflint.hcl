# EN: tflint configuration. Run: tflint --init && tflint --recursive
# FR : Configuration de tflint. Lancer : tflint --init && tflint --recursive

config {
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# EN: Azure-specific rules: invalid VM sizes, SKUs… Bump the version over time.
# FR : Règles propres à Azure : tailles de VM, SKU invalides… Mettez la version à jour avec le temps.
plugin "azurerm" {
  enabled = true
  version = "0.31.1"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}
