# EN: tflint configuration. Run: tflint --init && tflint --recursive
# FR : Configuration de tflint. Lancer : tflint --init && tflint --recursive

config {
  call_module_type = "local" # EN: also lint ./modules/* / FR : analyser aussi ./modules/*
}

# EN: Terraform language rules (bundled): unused declarations, missing types, deprecated syntax…
# FR : Règles du langage Terraform (intégrées) : déclarations inutilisées, types manquants, syntaxe obsolète…
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# EN: AWS-specific rules: invalid instance types, AMI formats, S3 names… Bump the version over time.
# FR : Règles propres à AWS : types d'instance invalides, formats d'AMI, noms S3… Mettez la version à jour avec le temps.
plugin "aws" {
  enabled = true
  version = "0.44.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}
