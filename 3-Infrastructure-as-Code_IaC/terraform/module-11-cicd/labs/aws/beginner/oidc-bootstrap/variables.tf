variable "github_repo" {
  description = "EN: Your practice repository, owner/name / FR: Votre dépôt d'entraînement, propriétaire/nom"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repo))
    error_message = "EN: Use the form owner/name, e.g. jdoe/tf-cicd-lab. / FR : Utilisez la forme propriétaire/nom, ex. jdoe/tf-cicd-lab."
  }
}

variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

variable "owner" {
  description = "EN: Owner tag / FR: Étiquette Owner"
  type        = string
  default     = "platform-team"
}

variable "state_bucket" {
  description = "EN: Module 3 state bucket; null = tfstate-<account>-<region> / FR: Compartiment d'état du module 3 ; null = tfstate-<compte>-<région>"
  type        = string
  default     = null
}

variable "state_prefix" {
  description = "EN: The only state keys CI may touch / FR: Les seules clés d'état que la CI peut toucher"
  type        = string
  default     = "module-11/aws"
}

# EN: One APPLY role per GitHub environment. "app" = intermediate lab; dev/prod = advanced lab.
# FR : Un rôle APPLY par environnement GitHub. « app » = lab intermédiaire ; dev/prod = lab avancé.
variable "environments" {
  description = "EN: GitHub environments that may apply / FR: Environnements GitHub autorisés à appliquer"
  type        = set(string)
  default     = ["app", "dev", "prod"]

  validation {
    condition     = alltrue([for e in var.environments : can(regex("^[a-z]{2,8}$", e))])
    error_message = "EN: 2-8 lowercase letters (used in resource names). / FR : 2 à 8 minuscules (utilisées dans les noms)."
  }
}

variable "create_oidc_provider" {
  description = "EN: false if your account already has the GitHub OIDC provider / FR: false si votre compte a déjà le fournisseur OIDC GitHub"
  type        = bool
  default     = true
}

# EN: Used by the Module 12 capstone: extra managed policies for apply roles, and extra state prefixes.
#     Defaults keep Module 11 exactly as it was.
# FR : Utilisé par le projet final (module 12) : politiques gérées supplémentaires pour les rôles apply,
#     et préfixes d'état supplémentaires. Les valeurs par défaut laissent le module 11 inchangé.
variable "extra_apply_policy_arns" {
  description = "EN: Environment → extra managed policy ARNs / FR: Environnement → ARN de politiques gérées supplémentaires"
  type        = map(list(string))
  default     = {}
}

variable "extra_state_prefixes" {
  description = "EN: More state prefixes CI may use, e.g. [\"capstone/aws\"] / FR: Autres préfixes d'état utilisables par la CI"
  type        = list(string)
  default     = []
}
