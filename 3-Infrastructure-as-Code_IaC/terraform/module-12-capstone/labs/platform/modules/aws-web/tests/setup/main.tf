# EN: Test helper: a unique suffix. / FR : Aide aux tests : un suffixe unique.
terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

resource "random_id" "suffix" {
  byte_length = 3
}

output "suffix" {
  value = random_id.suffix.hex
}
