# -----------------------------------------------------------------------------
# Lab 1.A-AWS — Controlling the resource lifecycle
# Lab 1.A-AWS — Contrôler le cycle de vie des ressources
#
# EN: Four `lifecycle` techniques used in production:
#       1. create_before_destroy  → zero-downtime replacement (security group)
#       2. ignore_changes         → let another system own a value (SSM parameter)
#       3. replace_triggered_by   → force replacement when something else changes
#       4. prevent_destroy        → protect critical data (S3 bucket)
#     Cost: ~$0 (security groups, standard SSM parameters and empty buckets are free).
# FR: Quatre techniques `lifecycle` utilisées en production :
#       1. create_before_destroy  → remplacement sans interruption (groupe de sécurité)
#       2. ignore_changes         → laisser un autre système gérer une valeur (paramètre SSM)
#       3. replace_triggered_by   → forcer un remplacement quand autre chose change
#       4. prevent_destroy        → protéger des données critiques (compartiment S3)
#     Coût : ~0 $ (groupes de sécurité, paramètres SSM standard et compartiments vides).
# -----------------------------------------------------------------------------

# EN: Uses your account's DEFAULT VPC. If you deleted it, recreate it with
#     `aws ec2 create-default-vpc`.
# FR: Utilise le VPC PAR DÉFAUT de votre compte. Si vous l'avez supprimé,
#     recréez-le avec `aws ec2 create-default-vpc`.
data "aws_vpc" "default" {
  default = true
}

# =============================================================================
# 1. create_before_destroy
# =============================================================================
# EN: `name_prefix` (not `name`) lets AWS generate a unique name, so the NEW
#     group can exist alongside the OLD one during replacement.
# FR: `name_prefix` (et non `name`) laisse AWS générer un nom unique, pour que le
#     NOUVEAU groupe puisse coexister avec l'ANCIEN pendant le remplacement.
resource "aws_security_group" "web" {
  name_prefix = "tf-lab-m01-web-"
  description = var.sg_description
  vpc_id      = data.aws_vpc.default.id

  lifecycle {
    create_before_destroy = true
  }
}

# EN: Modern style: one resource per rule (instead of inline ingress blocks).
# FR: Style moderne : une ressource par règle (au lieu de blocs ingress intégrés).
resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.web.id
  description       = "HTTPS from the VPC"
  cidr_ipv4         = data.aws_vpc.default.cidr_block
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# =============================================================================
# 2 + 3. ignore_changes + replace_triggered_by
# =============================================================================
# EN: terraform_data stores a value in state. When `input` changes, the
#     resource is replaced — a perfect trigger for replace_triggered_by.
# FR: terraform_data stocke une valeur dans l'état. Quand `input` change, la
#     ressource est remplacée — un déclencheur idéal pour replace_triggered_by.
resource "terraform_data" "release" {
  input = var.release_version
}

# EN: Terraform sets the INITIAL config; the application team may tune it
#     afterwards (ignore_changes). Every new release resets it to the baseline
#     (replace_triggered_by).
# FR: Terraform définit la configuration INITIALE ; l'équipe applicative peut
#     l'ajuster ensuite (ignore_changes). Chaque nouvelle version la
#     réinitialise à la référence (replace_triggered_by).
resource "aws_ssm_parameter" "app_config" {
  name = "/tf-lab/m01/app-config"
  type = "String"
  value = jsonencode({
    log_level    = "info"
    feature_beta = false
  })

  lifecycle {
    ignore_changes       = [value]
    replace_triggered_by = [terraform_data.release]
  }
}

# =============================================================================
# 4. prevent_destroy
# =============================================================================
resource "random_id" "suffix" {
  byte_length = 4
}

# EN: Any plan that would DESTROY this bucket (destroy or replace) fails.
#     Note: lifecycle arguments must be literal values — no variables allowed.
# FR: Tout plan qui DÉTRUIRAIT ce compartiment (destruction ou remplacement)
#     échoue. Note : les arguments lifecycle doivent être des valeurs
#     littérales — aucune variable autorisée.
resource "aws_s3_bucket" "critical" {
  bucket        = "tf-lab-m01-critical-${random_id.suffix.hex}"
  force_destroy = true # EN: lab only / FR: lab uniquement

  lifecycle {
    prevent_destroy = true
  }
}
