# -----------------------------------------------------------------------------
# Lab 7.B-AWS — A web server bootstrapped with user_data
# Lab 7.B-AWS — Un serveur web initialisé avec user_data
#
# EN: No provisioner, no SSH: the instance configures ITSELF at first boot.
#     Cost: t3.micro ≈ 1 cent/hour. DESTROY at the end of the lab.
# FR: Ni provisioner, ni SSH : l'instance se configure ELLE-MÊME au premier
#     démarrage. Coût : t3.micro ≈ 1 cent/heure. DÉTRUISEZ en fin de lab.
# -----------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_security_group" "web" {
  name_prefix = "tf-lab-m07-web-"
  description = "HTTP from the student's IP only"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  description       = "http-from-my-ip"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "${var.my_ip}/32"
}

# EN: Outbound is required to download packages (dnf).
# FR: Le trafic sortant est requis pour télécharger les paquets (dnf).
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    title   = "tf-lab-m07"
    message = var.page_message
  })

  # EN: user_data runs only at FIRST boot. Without this flag, changing it
  #     would update the attribute but never re-run the script. With it,
  #     Terraform REPLACES the instance → the new script runs (immutable).
  # FR: user_data ne s'exécute qu'au PREMIER démarrage. Sans cette option,
  #     le modifier changerait l'attribut sans jamais relancer le script.
  #     Avec elle, Terraform REMPLACE l'instance → le nouveau script s'exécute (immuable).
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "tf-lab-m07-web"
  }
}

output "url" {
  description = "EN: Web server URL (allow ~1-2 min for boot) / FR: URL du serveur web (prévoir ~1-2 min de démarrage)"
  value       = "http://${aws_instance.web.public_ip}"
}

output "instance_id" {
  description = "EN: Instance ID / FR: ID de l'instance"
  value       = aws_instance.web.id
}
