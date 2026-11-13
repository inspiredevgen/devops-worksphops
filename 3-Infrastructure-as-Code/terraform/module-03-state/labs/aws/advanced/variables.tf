variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

variable "legacy_bucket_name" {
  description = "EN: Bucket created by scripts/setup.sh / FR: Compartiment créé par scripts/setup.sh"
  type        = string
}

variable "legacy_sg_id" {
  description = "EN: Security group ID printed by scripts/setup.sh / FR: ID du groupe de sécurité affiché par scripts/setup.sh"
  type        = string

  validation {
    condition     = can(regex("^sg-[0-9a-f]+$", var.legacy_sg_id))
    error_message = "EN: Expected an ID like sg-0123abcd. / FR : ID attendu du type sg-0123abcd."
  }
}
