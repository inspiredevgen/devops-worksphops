variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

variable "environment" {
  description = "EN: Passed to the module / FR: Transmis au module"
  type        = string
  default     = "dev"
}

variable "force_destroy" {
  description = "EN: Passed to the module / FR: Transmis au module"
  type        = bool
  default     = true
}
