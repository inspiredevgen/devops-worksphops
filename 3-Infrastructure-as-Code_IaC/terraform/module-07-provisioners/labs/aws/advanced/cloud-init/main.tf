# -----------------------------------------------------------------------------
# Lab 7.A-AWS (part 1) — Multi-part cloud-init with the cloudinit provider
# Lab 7.A-AWS (partie 1) — cloud-init multi-parties avec le provider cloudinit
#
# EN: Part 1 = declarative cloud-config built with yamlencode() (always valid
#     YAML). Part 2 = a shell script for what YAML can't express.
#     Cost: t3.micro ≈ 1 cent/hour. DESTROY after.
# FR: Partie 1 = cloud-config déclaratif construit avec yamlencode() (YAML
#     toujours valide). Partie 2 = un script shell pour ce que le YAML ne peut
#     exprimer. Coût : t3.micro ≈ 1 cent/heure. DÉTRUISEZ ensuite.
# -----------------------------------------------------------------------------

locals {
  cloud_config = {
    package_update = true
    packages       = ["nginx"]

    # EN: write_files runs BEFORE packages are installed, and the nginx RPM ships
    #     its own index.html → stage the page in /opt; part 2 copies it into place.
    # FR: write_files s'exécute AVANT l'installation des paquets, et le RPM nginx
    #     fournit son propre index.html → déposer la page dans /opt ; la partie 2 la copie.
    write_files = [
      {
        path        = "/opt/tf-lab/index.html"
        permissions = "0644"
        content     = <<-HTML
          <!doctype html>
          <html><head><meta charset="utf-8"><title>tf-lab-m07</title></head>
          <body style="font-family: sans-serif; margin: 3rem;">
            <h1>tf-lab-m07 — ${var.environment}</h1>
            <p>AZ: __AZ__</p>
            <p>Bootstrapped by / Initialisé par : cloud-init multi-part</p>
          </body></html>
        HTML
      },
    ]

    runcmd = [
      "systemctl enable --now nginx",
    ]
  }
}

# EN: The REAL document sent to EC2: gzipped + base64 (smaller, max 16 KB).
# FR: Le VRAI document envoyé à EC2 : gzip + base64 (plus petit, 16 Ko max).
data "cloudinit_config" "web" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "cloud-config.yaml"
    content_type = "text/cloud-config"
    content      = yamlencode(local.cloud_config)
  }

  part {
    filename     = "configure.sh"
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/scripts/configure.sh.tftpl", { environment = var.environment })
  }
}

# EN: A READABLE copy of the same document, for `terraform console` / outputs.
# FR: Une copie LISIBLE du même document, pour `terraform console` / les sorties.
data "cloudinit_config" "preview" {
  gzip          = false
  base64_encode = false

  part {
    filename     = "cloud-config.yaml"
    content_type = "text/cloud-config"
    content      = yamlencode(local.cloud_config)
  }

  part {
    filename     = "configure.sh"
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/scripts/configure.sh.tftpl", { environment = var.environment })
  }
}

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
  name_prefix = "tf-lab-m07-ci-"
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
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  vpc_security_group_ids      = [aws_security_group.web.id]
  user_data_base64            = data.cloudinit_config.web.rendered
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required"
  }

  tags = { Name = "tf-lab-m07-cloud-init" }
}

# EN: How long until /healthz answers? Compare with the baked image (part 3).
# FR: Combien de temps avant que /healthz réponde ? Comparez avec l'image préconstruite (partie 3).
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

output "cloud_init_preview" {
  description = "EN: The multi-part document, readable / FR: Le document multi-parties, lisible"
  value       = data.cloudinit_config.preview.rendered
}
