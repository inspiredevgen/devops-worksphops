# EN: Every switch below breaks one policy. Flip them one at a time and run the gate.
# FR : Chaque interrupteur ci-dessous enfreint une politique. Basculez-les un par un et lancez la porte.

variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

variable "owner" {
  description = "EN: Owner tag; \"\" breaks tags.rego / FR: Étiquette Owner ; \"\" enfreint tags.rego"
  type        = string
  default     = "platform-team"
}

variable "ssh_from_anywhere" {
  description = "EN: true breaks network.rego / FR: true enfreint network.rego"
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "EN: e.g. m5.4xlarge breaks compute.rego / FR: ex. m5.4xlarge enfreint compute.rego"
  type        = string
  default     = "t3.micro"
}

variable "require_imdsv2" {
  description = "EN: false breaks compute.rego / FR: false enfreint compute.rego"
  type        = bool
  default     = true
}
