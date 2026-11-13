# =============================================================================
# EC2 lab hosts in the default VPC: IMDSv2, encrypted disks, tags that Ansible will use.
# Hôtes de lab EC2 dans le VPC par défaut : IMDSv2, disques chiffrés, étiquettes utilisées par Ansible.
# =============================================================================

data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  default = true
}

# EN: Official images, looked up through AWS's public SSM parameters (always the latest patch level).
# FR : Images officielles, trouvées via les paramètres SSM publics d'AWS (toujours le dernier correctif).
data "aws_ssm_parameter" "ami" {
  for_each = {
    ubuntu = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
    al2023 = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  }
  name = each.value
}

locals {
  ssh       = var.access == "ssh"
  proxyjump = var.access == "proxyjump"
  ssm       = var.access == "ssm"
  uses_key  = !local.ssm # EN: ssh and proxyjump log in with your key / FR : ssh et proxyjump utilisent votre clé
  # EN: Each distro has its own default login user. / FR : Chaque distribution a son propre utilisateur par défaut.
  login_user = { ubuntu = "ubuntu", al2023 = "ec2-user" }
}

resource "random_id" "suffix" {
  byte_length = 3
}

resource "aws_key_pair" "lab" {
  count = local.uses_key ? 1 : 0

  key_name   = "ans-lab-${random_id.suffix.hex}"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "aws_security_group" "lab" {
  name        = "ans-lab-${random_id.suffix.hex}"
  description = "Ansible lab hosts"
  vpc_id      = data.aws_vpc.default.id
  tags        = { Name = "ans-lab-${random_id.suffix.hex}" }

  lifecycle {
    precondition {
      condition     = local.ssm || var.my_ip != null
      error_message = "EN: ssh and proxyjump modes need my_ip. / FR : les modes ssh et proxyjump exigent my_ip."
    }
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  count = local.ssh ? 1 : 0

  security_group_id = aws_security_group.lab.id
  description       = "SSH from the control node only"
  cidr_ipv4         = "${var.my_ip}/32"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

# EN: Lab hosts download packages and releases from the internet; production would use VPC endpoints + a proxy.
# FR : Les hôtes de lab téléchargent paquets et versions depuis Internet ; en production : points de terminaison VPC + proxy.
#trivy:ignore:AWS-0104
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.lab.id
  description       = "Packages, and the SSM endpoints in ssm mode"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "host" {
  for_each = var.hosts

  ami                    = data.aws_ssm_parameter.ami[each.value.os].insecure_value
  instance_type          = var.instance_type
  key_name               = local.uses_key ? aws_key_pair.lab[0].key_name : null
  vpc_security_group_ids = [aws_security_group.lab.id]
  # EN: proxyjump: no public IP, so also NO internet (no NAT here): fine for Module 1 ad-hoc work, not for package installs.
  #     ssm: needs outbound internet to reach the SSM endpoints.
  # FR : proxyjump : pas d'IP publique, donc PAS d'Internet (pas de NAT) : bien pour le module 1, pas pour installer des paquets.
  #     ssm : a besoin d'Internet sortant pour joindre les points de terminaison SSM.
  associate_public_ip_address = !local.proxyjump
  iam_instance_profile        = local.ssm ? aws_iam_instance_profile.ssm[0].name : null

  metadata_options {
    http_tokens = "required"
    # EN: Expose the instance's tags in IMDS (/latest/meta-data/tags/instance): Module 3 reads them from inside.
    # FR : Expose les étiquettes de l'instance dans l'IMDS : le module 3 les lit depuis l'intérieur.
    instance_metadata_tags = "enabled"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = merge(each.value.tags, {
    Name        = "ans-lab-${each.key}"
    Host        = each.key # EN: the inventory hostname for dynamic inventory (Module 4) / FR : le nom d'hôte d'inventaire
    Role        = each.value.role
    Environment = each.value.environment
    OS          = each.value.os
  })
}

# =============================================================================
# proxyjump mode only: one small jump host is the ONLY thing reachable from the internet.
# Mode proxyjump seulement : un petit hôte de rebond est la SEULE chose joignable depuis Internet.
# =============================================================================

resource "aws_security_group" "jump" {
  count = local.proxyjump ? 1 : 0

  name        = "ans-lab-jump-${random_id.suffix.hex}"
  description = "Ansible lab jump host"
  vpc_id      = data.aws_vpc.default.id
  tags        = { Name = "ans-lab-jump-${random_id.suffix.hex}" }
}

resource "aws_vpc_security_group_ingress_rule" "jump_from_me" {
  count = local.proxyjump ? 1 : 0

  security_group_id = aws_security_group.jump[0].id
  description       = "SSH to the jump host from the control node only"
  cidr_ipv4         = "${var.my_ip}/32"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "jump_all" {
  count = local.proxyjump ? 1 : 0

  security_group_id = aws_security_group.jump[0].id
  description       = "SSH onward to the lab hosts"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# EN: The lab hosts accept SSH ONLY from members of the jump security group (no CIDR at all).
# FR : Les hôtes de lab acceptent SSH SEULEMENT des membres du groupe de sécurité de rebond (aucun CIDR).
resource "aws_vpc_security_group_ingress_rule" "hosts_from_jump" {
  count = local.proxyjump ? 1 : 0

  security_group_id            = aws_security_group.lab.id
  description                  = "SSH from the jump host only"
  referenced_security_group_id = aws_security_group.jump[0].id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

resource "aws_instance" "jump" {
  count = local.proxyjump ? 1 : 0

  ami                         = data.aws_ssm_parameter.ami["ubuntu"].insecure_value
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.lab[0].key_name
  vpc_security_group_ids      = [aws_security_group.jump[0].id]
  associate_public_ip_address = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = {
    Name = "ans-lab-jump"
    Role = "jump"
  }
}

resource "aws_vpc_security_group_ingress_rule" "extra" {
  for_each = local.ssh ? toset([for p in var.open_ports : tostring(p)]) : toset([])

  security_group_id = aws_security_group.lab.id
  description       = "Lab port ${each.value} from the control node only"
  cidr_ipv4         = "${var.my_ip}/32"
  ip_protocol       = "tcp"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
}
