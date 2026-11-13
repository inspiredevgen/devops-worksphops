# =============================================================================
# Lab 8.A-AWS — Hub-and-spoke with Transit Gateway, segmentation and private DNS
# Lab 8.A-AWS — Hub-and-spoke avec Transit Gateway, segmentation et DNS privé
#
#                 ┌──────────── shared (hub) ────────────┐
#                 │                                      │
#        app ─────┤        Transit Gateway               ├───── data
#                 │  rt-shared: learns app + data        │
#                 │  rt-spokes: learns ONLY shared       │
#                 └──────────────────────────────────────┘
#   EN: app ↔ shared ✅   data ↔ shared ✅   app ↔ data ❌ (segmented)
#   FR : app ↔ shared ✅   data ↔ shared ✅   app ↔ data ❌ (segmenté)
# =============================================================================

locals {
  name   = "tf-lab-m08-hub"
  spokes = toset([for k in keys(var.vpcs) : k if k != "shared"])
}

module "vpc" {
  source   = "./modules/network"
  for_each = var.vpcs

  name                = "${local.name}-${each.key}"
  cidr                = each.value
  public_subnets      = false # EN: no internet edge in this lab / FR : pas d'accès Internet dans ce lab
  s3_gateway_endpoint = true
}

# ---------------------------------------------------------------- Transit Gateway
resource "aws_ec2_transit_gateway" "this" {
  description = "Course lab hub"

  # EN: Turn OFF the defaults: we want to decide routing ourselves (segmentation).
  # FR : Désactiver les valeurs par défaut : nous voulons décider nous-mêmes du routage (segmentation).
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"

  tags = { Name = "${local.name}-tgw" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  for_each = module.vpc

  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = each.value.vpc_id
  subnet_ids         = each.value.private_subnet_ids

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = { Name = "${local.name}-attach-${each.key}" }
}

resource "aws_ec2_transit_gateway_route_table" "shared" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "${local.name}-rt-shared" }
}

resource "aws_ec2_transit_gateway_route_table" "spokes" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "${local.name}-rt-spokes" }
}

# EN: ASSOCIATION = "which route table does traffic FROM this attachment use?"
# FR : ASSOCIATION = « quelle table de routage utilise le trafic VENANT de cet attachement ? »
resource "aws_ec2_transit_gateway_route_table_association" "this" {
  for_each = var.vpcs

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[each.key].id
  transit_gateway_route_table_id = each.key == "shared" ? aws_ec2_transit_gateway_route_table.shared.id : aws_ec2_transit_gateway_route_table.spokes.id
}

# EN: PROPAGATION = "which route tables LEARN this attachment's CIDR?"
#     Spokes propagate into rt-shared; shared propagates into rt-spokes. Spokes never learn each other.
# FR : PROPAGATION = « quelles tables de routage APPRENNENT le CIDR de cet attachement ? »
#     Les rayons se propagent dans rt-shared ; shared se propage dans rt-spokes. Les rayons ne s'apprennent jamais entre eux.
resource "aws_ec2_transit_gateway_route_table_propagation" "spoke_to_shared" {
  for_each = local.spokes

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "shared_to_spokes" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this["shared"].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}

# ------------------------------------------- VPC side: supernet → TGW, every table
locals {
  vpc_routes = merge([
    for vpc, m in module.vpc : {
      for rt in m.route_table_keys : "${vpc}/${rt}" => { vpc = vpc, rt = rt }
    }
  ]...)
}

resource "aws_route" "to_tgw" {
  for_each = local.vpc_routes

  route_table_id         = module.vpc[each.value.vpc].route_table_ids[each.value.rt]
  destination_cidr_block = var.supernet
  transit_gateway_id     = aws_ec2_transit_gateway.this.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}

# ------------------------------------------------------- Private DNS for all VPCs
resource "aws_route53_zone" "private" {
  name    = var.private_zone
  comment = "Course lab private zone"

  dynamic "vpc" {
    for_each = module.vpc
    content {
      vpc_id = vpc.value.vpc_id
    }
  }
}

# EN: Example records: services resolve by name from EVERY VPC, but only exist in the zone.
# FR : Enregistrements d'exemple : les services se résolvent par nom depuis CHAQUE VPC, mais n'existent que dans la zone.
resource "aws_route53_record" "service" {
  for_each = var.vpcs

  zone_id = aws_route53_zone.private.zone_id
  name    = "${each.key}.${var.private_zone}"
  type    = "A"
  ttl     = 60
  records = [cidrhost(each.value, 10)]
}

# -------------------------------------------------------------------- Outputs
output "tgw_route_tables" {
  value = {
    shared = aws_ec2_transit_gateway_route_table.shared.id
    spokes = aws_ec2_transit_gateway_route_table.spokes.id
  }
}

output "verify_commands" {
  value = {
    shared_learns = "aws ec2 search-transit-gateway-routes --transit-gateway-route-table-id ${aws_ec2_transit_gateway_route_table.shared.id} --filters Name=state,Values=active --query 'Routes[].DestinationCidrBlock' --output text"
    spokes_learn  = "aws ec2 search-transit-gateway-routes --transit-gateway-route-table-id ${aws_ec2_transit_gateway_route_table.spokes.id} --filters Name=state,Values=active --query 'Routes[].DestinationCidrBlock' --output text"
    dns_records   = "aws route53 list-resource-record-sets --hosted-zone-id ${aws_route53_zone.private.zone_id} --query \"ResourceRecordSets[?Type=='A'].[Name,ResourceRecords[0].Value]\" --output text"
  }
}
