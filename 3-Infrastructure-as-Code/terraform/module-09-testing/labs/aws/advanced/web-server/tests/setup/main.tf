# EN: Test helper: unique names and the caller's IP. Never deployed on its own.
# FR : Aide aux tests : noms uniques et IP de l'appelant. Jamais déployé seul.
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
  }
}

resource "random_id" "suffix" {
  byte_length = 3
}

data "http" "my_ip" {
  url = "https://api.ipify.org"
}

output "suffix" {
  value = random_id.suffix.hex
}

output "my_ip" {
  value = chomp(data.http.my_ip.response_body)
}
