# EN: Test helper: unique suffix, the caller's IP and a THROW-AWAY SSH key (no file on disk needed in CI).
# FR : Aide aux tests : suffixe unique, IP de l'appelant et une clé SSH JETABLE (aucun fichier requis en CI).
terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
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

data "http" "my_ip" {
  url = "https://api.ipify.org"
}

output "suffix" {
  value = random_string.suffix.result
}

output "my_ip" {
  value = chomp(data.http.my_ip.response_body)
}

output "ssh_public_key" {
  value = chomp(tls_private_key.ssh.public_key_openssh)
}
