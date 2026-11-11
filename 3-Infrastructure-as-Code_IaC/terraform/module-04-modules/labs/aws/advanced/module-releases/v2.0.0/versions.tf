# -----------------------------------------------------------------------------
# EN: A CHILD module declares the providers it needs and the MINIMUM versions
#     it supports (>=) — it NEVER contains a `provider` block. The ROOT module
#     configures providers and pins exact ranges (~>).
# FR: Un module ENFANT déclare les providers dont il a besoin et les versions
#     MINIMALES prises en charge (>=) — il ne contient JAMAIS de bloc
#     `provider`. Le module RACINE configure les providers et épingle les plages (~>).
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}
