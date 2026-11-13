# EN: Test helper: fetch a URL, retrying while the server boots (up to ~5 minutes).
# FR : Aide aux tests : récupérer une URL, en réessayant pendant le démarrage du serveur (jusqu'à ~5 minutes).
terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

variable "url" {
  description = "EN: URL to fetch / FR: URL à récupérer"
  type        = string
}

variable "expected_text" {
  description = "EN: Text the page must contain / FR: Texte que la page doit contenir"
  type        = string
}

data "http" "page" {
  url = var.url

  retry {
    attempts     = 30
    min_delay_ms = 10000
    max_delay_ms = 10000
  }
}

output "status_code" {
  value = data.http.page.status_code
}

output "contains_expected" {
  value = strcontains(data.http.page.response_body, var.expected_text)
}
