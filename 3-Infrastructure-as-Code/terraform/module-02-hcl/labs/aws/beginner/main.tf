# -----------------------------------------------------------------------------
# Lab 2.B-AWS — An EC2 instance driven by variables, data sources and outputs
# Lab 2.B-AWS — Une instance EC2 pilotée par des variables, sources de données et sorties
#
# EN: Cost: t3.micro ≈ 1 cent/hour in ca-central-1 (covered by Free Tier
#     credits on eligible accounts). DESTROY at the end of the lab.
# FR: Coût : t3.micro ≈ 1 cent/heure dans ca-central-1 (couvert par les crédits
#     de l'offre gratuite sur les comptes admissibles). DÉTRUISEZ en fin de lab.
# -----------------------------------------------------------------------------

# EN: DATA SOURCE — look up the latest Amazon Linux 2023 AMI instead of
#     hard-coding an ID (AMI IDs differ per region and change over time).
# FR: SOURCE DE DONNÉES — chercher la dernière AMI Amazon Linux 2023 au lieu de
#     coder un ID en dur (les ID d'AMI varient selon la région et dans le temps).
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"] # EN: only official images / FR: images officielles uniquement

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.al2023.id
  instance_type = var.instance_type
  monitoring    = var.enable_detailed_monitoring

  # EN: No subnet given → AWS uses a default subnet of the default VPC.
  # FR: Aucun sous-réseau indiqué → AWS utilise un sous-réseau par défaut du VPC par défaut.

  # EN: Require IMDSv2 (session tokens) — a security best practice.
  # FR: Exiger IMDSv2 (jetons de session) — une bonne pratique de sécurité.
  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = var.root_volume_size_gb
    volume_type = "gp3"
    encrypted   = true
  }

  # EN: String interpolation: "${...}" inserts an expression into a string.
  # FR: Interpolation : "${...}" insère une expression dans une chaîne.
  tags = {
    Name        = "${var.project_name}-${var.environment}-web"
    Environment = var.environment
  }
}
