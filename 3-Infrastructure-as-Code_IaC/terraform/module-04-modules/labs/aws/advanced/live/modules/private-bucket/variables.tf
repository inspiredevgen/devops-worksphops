variable "name_prefix" {
  description = "EN: Bucket name prefix (account ID is appended) / FR: Préfixe du nom (l'ID de compte est ajouté)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,40}$", var.name_prefix))
    error_message = "EN: 3-41 chars, lowercase, digits, hyphens. / FR : 3 à 41 caractères, minuscules, chiffres, tirets."
  }
}

# -----------------------------------------------------------------------------
# EN: WHY TWO INPUTS? `count` must be known at PLAN time. The endpoint ID is
#     only known AFTER apply when the endpoint is created in the same run, so
#     a plain bool decides whether the policy exists, and the ID fills it in.
# FR: POURQUOI DEUX ENTRÉES ? `count` doit être connu au moment du PLAN. L'ID
#     du point de terminaison n'est connu qu'APRÈS l'apply s'il est créé dans
#     la même exécution : un simple booléen décide donc si la politique existe,
#     et l'ID la complète.
# -----------------------------------------------------------------------------
variable "restrict_to_vpc_endpoint" {
  description = "EN: Deny object reads/writes from outside the VPC endpoint / FR: Refuser lectures/écritures d'objets hors du point de terminaison VPC"
  type        = bool
  default     = false
}

variable "vpc_endpoint_id" {
  description = "EN: S3 gateway endpoint ID (required when restricting) / FR: ID du point de terminaison S3 (requis si restriction)"
  type        = string
  default     = null
}

variable "tags" {
  description = "EN: Extra tags / FR: Étiquettes supplémentaires"
  type        = map(string)
  default     = {}
}
