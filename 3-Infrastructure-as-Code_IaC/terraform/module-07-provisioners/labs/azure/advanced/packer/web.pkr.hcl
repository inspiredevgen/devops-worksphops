# -----------------------------------------------------------------------------
# Lab 7.A-AZ (part 2) — Bake a "golden" managed image with Packer
# Lab 7.A-AZ (partie 2) — Construire une image managée « golden » avec Packer
#
# EN: Prerequisite: the destination resource group must exist:
#       az group create -n rg-tf-lab-m07-images -l canadacentral
#     Credentials are read from the same ARM_* variables as Terraform.
#       packer init .  &&  packer validate .  &&  packer build .
#     Cost: a few cents for the build VM + ~$1-2/month for the 30 GB image
#     → delete the image after the lab.
# FR: Prérequis : le groupe de ressources de destination doit exister :
#       az group create -n rg-tf-lab-m07-images -l canadacentral
#     Les identifiants sont lus dans les mêmes variables ARM_* que Terraform.
#       packer init .  &&  packer validate .  &&  packer build .
#     Coût : quelques cents pour la VM de construction + ~1-2 $/mois pour
#     l'image de 30 Go → supprimez l'image après le lab.
# -----------------------------------------------------------------------------

packer {
  required_plugins {
    azure = {
      version = ">= 2.1.0"
      source  = "github.com/hashicorp/azure"
    }
  }
}

# EN: env() is only allowed in variable defaults.
# FR: env() n'est autorisé que dans les valeurs par défaut des variables.
variable "client_id" {
  type    = string
  default = env("ARM_CLIENT_ID")
}

variable "client_secret" {
  type      = string
  default   = env("ARM_CLIENT_SECRET")
  sensitive = true
}

variable "tenant_id" {
  type    = string
  default = env("ARM_TENANT_ID")
}

variable "subscription_id" {
  type    = string
  default = env("ARM_SUBSCRIPTION_ID")
}

variable "location" {
  type    = string
  default = "canadacentral"
}

variable "images_resource_group" {
  type    = string
  default = "rg-tf-lab-m07-images"
}

locals {
  timestamp = formatdate("YYYYMMDDhhmmss", timestamp())
}

source "azure-arm" "web" {
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id

  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "ubuntu-24_04-lts"
  image_sku       = "server"

  location = var.location
  vm_size  = "Standard_B2s"

  # EN: Terraform finds the image by this name prefix (baked/main.tf).
  # FR: Terraform retrouve l'image grâce à ce préfixe de nom (baked/main.tf).
  managed_image_name                = "img-tf-lab-m07-web-${local.timestamp}"
  managed_image_resource_group_name = var.images_resource_group

  azure_tags = {
    role    = "tf-lab-m07-web"
    builder = "packer"
    course  = "terraform-cloud-engineer"
  }
}

build {
  sources = ["source.azure-arm.web"]

  provisioner "shell" {
    script          = "${path.root}/scripts/install-web.sh"
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
  }

  # EN: MANDATORY last step for Azure Linux images: generalize (remove the
  #     build user, machine identity, etc.) so new VMs can be created from it.
  # FR: Dernière étape OBLIGATOIRE pour les images Linux Azure : généraliser
  #     (retirer l'utilisateur de construction, l'identité de la machine, etc.)
  #     pour pouvoir créer de nouvelles VM à partir de l'image.
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline          = ["/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"]
    inline_shebang  = "/bin/sh -x"
  }
}
