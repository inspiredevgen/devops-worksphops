variable "environment" {
  description = "EN: app, dev or prod; must match the CI role's naming scope / FR: app, dev ou prod ; doit correspondre à la portée de nommage du rôle CI"
  type        = string

  validation {
    condition     = contains(["app", "dev", "prod"], var.environment)
    error_message = "EN: environment must be app, dev or prod. / FR : environment doit valoir app, dev ou prod."
  }
}

variable "message" {
  description = "EN: A setting the app reads at runtime / FR: Un paramètre que l'application lit à l'exécution"
  type        = string
}
