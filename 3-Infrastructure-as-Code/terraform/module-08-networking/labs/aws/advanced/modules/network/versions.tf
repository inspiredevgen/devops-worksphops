# EN: A module declares WHICH providers it needs, never HOW they are configured.
#     The caller decides the region by passing a provider (see providers = { … } in the root).
# FR : Un module déclare QUELS providers il utilise, jamais COMMENT ils sont configurés.
#     L'appelant choisit la région en passant un provider (voir providers = { … } dans la racine).
terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
