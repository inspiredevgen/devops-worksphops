# =============================================================================
# Lab 12.A-AWS — Multi-cloud active/passive with Route 53 failover records (needs a domain)
# Lab 12.A-AWS — Multi-cloud actif/passif avec les enregistrements de bascule Route 53 (nom de domaine requis)
#
#   app.<zone> ── PRIMARY record   (healthy?) ──► the primary cloud
#              └─ SECONDARY record (used only when the primary's health check fails) ──► the other cloud
# =============================================================================

data "aws_route53_zone" "this" {
  name         = var.zone_name
  private_zone = false
}

locals {
  fqdn = "${var.record_name}.${var.zone_name}"
  role = {
    aws   = var.primary == "aws" ? "PRIMARY" : "SECONDARY"
    azure = var.primary == "azure" ? "PRIMARY" : "SECONDARY"
  }
}

# EN: Route 53's checkers probe from around the world; 2 failures × 10 s ≈ 20-30 s to detect an outage.
# FR : Les vérificateurs de Route 53 sondent depuis le monde entier ; 2 échecs × 10 s ≈ 20-30 s pour détecter une panne.
resource "aws_route53_health_check" "aws" {
  fqdn              = var.aws_alb_dns_name
  type              = "HTTP"
  port              = 80
  resource_path     = "/healthz"
  request_interval  = 10
  failure_threshold = 2
  tags              = { Name = "tf-capstone-aws" }
}

resource "aws_route53_health_check" "azure" {
  ip_address        = var.azure_ip
  type              = "HTTP"
  port              = 80
  resource_path     = "/healthz"
  request_interval  = 10
  failure_threshold = 2
  tags              = { Name = "tf-capstone-azure" }
}

# EN: AWS side: an ALIAS record (free queries, follows the ALB's changing IPs).
# FR : Côté AWS : un enregistrement ALIAS (requêtes gratuites, suit les IP changeantes de l'ALB).
resource "aws_route53_record" "aws" {
  zone_id         = data.aws_route53_zone.this.zone_id
  name            = local.fqdn
  type            = "A"
  set_identifier  = "aws"
  health_check_id = aws_route53_health_check.aws.id

  failover_routing_policy {
    type = local.role.aws
  }

  alias {
    name                   = var.aws_alb_dns_name
    zone_id                = var.aws_alb_zone_id
    evaluate_target_health = true
  }
}

# EN: Azure side: a plain A record to the load balancer's static IP, short TTL.
# FR : Côté Azure : un simple enregistrement A vers l'IP statique de l'équilibreur, TTL court.
resource "aws_route53_record" "azure" {
  #checkov:skip=CKV2_AWS_23:The target is the Azure load balancer's IP, outside AWS by design.
  zone_id         = data.aws_route53_zone.this.zone_id
  name            = local.fqdn
  type            = "A"
  ttl             = 30
  records         = [var.azure_ip]
  set_identifier  = "azure"
  health_check_id = aws_route53_health_check.azure.id

  failover_routing_policy {
    type = local.role.azure
  }
}
