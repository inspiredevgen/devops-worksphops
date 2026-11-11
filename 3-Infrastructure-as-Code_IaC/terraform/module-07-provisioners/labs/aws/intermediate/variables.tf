variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

# EN: Only YOUR IP may reach the web server. Find it: curl -s https://api.ipify.org
# FR: Seule VOTRE IP peut joindre le serveur web. Trouvez-la : curl -s https://api.ipify.org
variable "my_ip" {
  description = "EN: Your public IPv4 (no /32) / FR: Votre IPv4 publique (sans /32)"
  type        = string

  validation {
    condition     = can(cidrhost("${var.my_ip}/32", 0))
    error_message = "EN: A plain IPv4 address, e.g. 203.0.113.10. / FR : Une adresse IPv4 simple, ex. 203.0.113.10."
  }
}

variable "page_message" {
  description = "EN: Message shown on the web page / FR: Message affiché sur la page web"
  type        = string
  default     = "Hello from user_data! / Bonjour depuis user_data !"
}

# EN: Port the smoke test probes. Set it to 8080 on purpose to see a FAILED
#     provisioner (and a TAINTED resource).
# FR: Port testé par le test de fumée. Mettez 8080 exprès pour voir un
#     provisioner ÉCHOUER (et une ressource MARQUÉE « tainted »).
variable "smoke_test_port" {
  description = "EN: Port to probe / FR: Port à tester"
  type        = number
  default     = 80
}

variable "smoke_test_attempts" {
  description = "EN: Attempts (5 s apart) before failing / FR: Tentatives (espacées de 5 s) avant échec"
  type        = number
  default     = 40
}
