# -----------------------------------------------------------------------------
# Lab 7.A-AWS (part 2) — Bake a "golden" AMI with Packer
# Lab 7.A-AWS (partie 2) — Construire une AMI « golden » avec Packer
#
# EN: Packer launches a temporary instance, runs provisioners, snapshots it
#     into an AMI, then deletes the temporary resources.
#       packer init .  &&  packer validate .  &&  packer build .
#     Cost: a few cents for the build + ~$0.40/month per 8 GB snapshot
#     → deregister the AMI and delete its snapshot after the lab.
# FR: Packer lance une instance temporaire, exécute les provisioners, en fait
#     un instantané (AMI), puis supprime les ressources temporaires.
#       packer init .  &&  packer validate .  &&  packer build .
#     Coût : quelques cents pour la construction + ~0,40 $/mois par instantané
#     de 8 Go → désenregistrez l'AMI et supprimez l'instantané après le lab.
# -----------------------------------------------------------------------------

packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "ca-central-1"
}

locals {
  timestamp = formatdate("YYYYMMDDhhmmss", timestamp())
}

# EN: Packer data source: the latest Amazon Linux 2023 base image.
# FR: Source de données Packer : la dernière image de base Amazon Linux 2023.
data "amazon-ami" "al2023" {
  region      = var.aws_region
  owners      = ["amazon"]
  most_recent = true

  filters = {
    name                = "al2023-ami-2023.*-x86_64"
    virtualization-type = "hvm"
    root-device-type    = "ebs"
  }
}

source "amazon-ebs" "web" {
  region        = var.aws_region
  source_ami    = data.amazon-ami.al2023.id
  instance_type = "t3.micro"
  ssh_username  = "ec2-user"

  ami_name        = "tf-lab-m07-web-${local.timestamp}"
  ami_description = "tf-lab-m07 golden web image (nginx preinstalled)"
  imds_support    = "v2.0"

  # EN: The temporary SSH security group only allows YOUR public IP.
  # FR: Le groupe de sécurité SSH temporaire n'autorise que VOTRE IP publique.
  temporary_security_group_source_public_ip = true

  # EN: Terraform finds the image through these tags (baked/main.tf).
  # FR: Terraform retrouve l'image grâce à ces étiquettes (baked/main.tf).
  tags = {
    Role      = "tf-lab-m07-web"
    Builder   = "packer"
    Base_AMI  = data.amazon-ami.al2023.id
    Course    = "terraform-cloud-engineer"
    BuildTime = local.timestamp
  }

  run_tags = {
    Name = "packer-tf-lab-m07"
  }
}

build {
  sources = ["source.amazon-ebs.web"]

  provisioner "shell" {
    script          = "${path.root}/scripts/install-web.sh"
    execute_command = "sudo -E bash '{{ .Path }}'"
  }

  # EN: Writes the AMI ID to manifest.json (handy for pipelines).
  # FR: Écrit l'ID de l'AMI dans manifest.json (pratique pour les pipelines).
  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
