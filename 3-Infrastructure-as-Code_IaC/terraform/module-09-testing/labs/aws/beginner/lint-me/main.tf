# =============================================================================
# EN: LINT-ME: valid Terraform with SEVERAL problems. `terraform validate` passes; tflint does not.
#     NEVER apply this folder. Fix it until `tflint --chdir=lint-me` is clean.
# FR : LINT-ME : du Terraform valide avec PLUSIEURS problèmes. `terraform validate` passe ; tflint, non.
#     N'appliquez JAMAIS ce dossier. Corrigez-le jusqu'à ce que `tflint --chdir=lint-me` soit propre.
# =============================================================================

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "instanceName" {
  default = "web"
}

variable "unused_port" {
  type    = number
  default = 8080
}

resource "aws_instance" "Web" {
  ami           = "ami-0123456789abcdef0"
  instance_type = "t3.mircro"

  tags = {
    Name = "${var.instanceName}"
  }
}
