variable "environment" {
  description = "EN: app, dev or prod; selects the pre-created rg-tf-cicd-<env> / FR: app, dev ou prod ; choisit le rg-tf-cicd-<env> créé à l'avance"
  type        = string

  validation {
    condition     = contains(["app", "dev", "prod"], var.environment)
    error_message = "EN: environment must be app, dev or prod. / FR : environment doit valoir app, dev ou prod."
  }
}

variable "tags" {
  description = "EN: Tags for every resource / FR: Étiquettes de chaque ressource"
  type        = map(string)
}
