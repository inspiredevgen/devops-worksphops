# EN: Test helper: a unique suffix and a THROW-AWAY SSH key. / FR : Aide aux tests : un suffixe unique et une clé SSH JETABLE.
terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

output "suffix" {
  value = random_string.suffix.result
}

output "ssh_public_key" {
  value = chomp(tls_private_key.ssh.public_key_openssh)
}
