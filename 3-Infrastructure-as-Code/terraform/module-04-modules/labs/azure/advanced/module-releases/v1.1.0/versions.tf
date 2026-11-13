# -----------------------------------------------------------------------------
# EN: A CHILD module declares required providers with MINIMUM versions (>=)
#     and NEVER contains a `provider` block.
# FR: Un module ENFANT déclare ses providers avec des versions MINIMALES (>=)
#     et ne contient JAMAIS de bloc `provider`.
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
  }
}
