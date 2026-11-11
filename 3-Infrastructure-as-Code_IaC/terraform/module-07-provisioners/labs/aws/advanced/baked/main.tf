# -----------------------------------------------------------------------------
# Lab 7.A-AWS (part 3) — Deploy the baked image
# Lab 7.A-AWS (partie 3) — Déployer l'image préconstruite
#
# EN: SOFTWARE is in the image (built once, tested once). CONFIGURATION is
#     injected at boot by a tiny user_data. Result: faster, more predictable
#     boots — no package downloads at launch.
#     Cost: t3.micro ≈ 1 cent/hour. DESTROY after.
# FR: Le LOGICIEL est dans l'image (construite une fois, testée une fois). La
#     CONFIGURATION est injectée au démarrage par un petit user_data.
#     Résultat : démarrages plus rapides et prévisibles — aucun téléchargement
#     de paquets au lancement. Coût : t3.micro ≈ 1 cent/heure. DÉTRUISEZ ensuite.
# -----------------------------------------------------------------------------

# EN: The newest AMI that YOU built (owners = self) with the Packer tag.
# FR: L'AMI la plus récente que VOUS avez construite (owners = self) avec l'étiquette Packer.
data "aws_ami" "web" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "tag:Role"
    values = ["tf-lab-m07-web"]
  }
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "web" {
  name_prefix = "tf-lab-m07-baked-"
  description = "HTTP from the student's IP only"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "${var.my_ip}/32"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.web.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web.id]

  # EN: CONFIG only — nginx is already installed and enabled in the image.
  # FR: CONFIGURATION seulement — nginx est déjà installé et activé dans l'image.
  user_data = join("\n", ["#cloud-config", yamlencode({
    write_files = [{
      path        = "/usr/share/nginx/html/index.html"
      permissions = "0644"
      content     = "<!doctype html><meta charset=\"utf-8\"><h1>tf-lab-m07 (baked)</h1><p>${var.page_message}</p><p>AMI: ${data.aws_ami.web.name}</p>"
    }]
  })])
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required"
  }

  tags = { Name = "tf-lab-m07-baked" }
}

resource "terraform_data" "time_to_healthy" {
  triggers_replace = [aws_instance.web.id]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = { URL = "http://${aws_instance.web.public_ip}/healthz" }
    command     = <<-EOT
      for i in $(seq 1 60); do
        if curl -sf -m 5 "$URL" >/dev/null; then echo "HEALTHY after $SECONDS s"; exit 0; fi
        sleep 5
      done
      echo "NOT healthy after $SECONDS s"; exit 1
    EOT
  }
}

output "url" {
  description = "EN: Web server URL / FR: URL du serveur web"
  value       = "http://${aws_instance.web.public_ip}"
}

output "ami" {
  description = "EN: Golden image used / FR: Image golden utilisée"
  value       = "${data.aws_ami.web.id} (${data.aws_ami.web.name})"
}
