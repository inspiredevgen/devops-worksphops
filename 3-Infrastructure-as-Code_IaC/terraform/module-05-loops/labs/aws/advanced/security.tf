# -----------------------------------------------------------------------------
# Lab 5.A-AWS (part 1) — Security groups generated from data
# Lab 5.A-AWS (partie 1) — Groupes de sécurité générés à partir de données
#
# EN: Rules are SEPARATE resources (aws_vpc_security_group_ingress_rule), not
#     inline blocks. Why? A rule may reference ANOTHER group of the same
#     for_each (app ← web). Inline blocks inside aws_security_group.this would
#     create a dependency CYCLE. Separate resources don't.
#     Cost: $0 (security groups are free; nothing is attached).
# FR: Les règles sont des ressources SÉPARÉES (aws_vpc_security_group_ingress_rule),
#     pas des blocs intégrés. Pourquoi ? Une règle peut référencer UN AUTRE groupe
#     du même for_each (app ← web). Des blocs intégrés dans aws_security_group.this
#     créeraient un CYCLE de dépendances. Les ressources séparées, non.
#     Coût : 0 $ (groupes de sécurité gratuits ; rien n'y est attaché).
# -----------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

locals {
  # EN: Flatten { tier => { ingress = [rules] } } into ONE map of rules keyed "tier/rule".
  # FR: Aplatir { niveau => { ingress = [règles] } } en UNE map de règles indexée « niveau/règle ».
  ingress_rules = {
    for r in flatten([
      for sg_key, sg in var.security_groups : [
        for rule in sg.ingress : merge(rule, { sg_key = sg_key })
      ]
    ]) : "${r.sg_key}/${r.name}" => r
  }
}

resource "aws_security_group" "this" {
  for_each = var.security_groups

  name_prefix = "tf-lab-m05-${each.key}-"
  description = each.value.description
  vpc_id      = data.aws_vpc.default.id

  tags = { Name = "sg-tf-lab-m05-${each.key}", Tier = each.key }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = local.ingress_rules

  security_group_id = aws_security_group.this[each.value.sg_key].id
  description       = each.value.name
  ip_protocol       = each.value.protocol
  from_port         = each.value.port
  to_port           = coalesce(each.value.to_port, each.value.port)

  # EN: Exactly one of these is non-null (enforced by validation).
  # FR: Exactement une de ces valeurs est non nulle (imposé par la validation).
  cidr_ipv4                    = each.value.cidr
  referenced_security_group_id = each.value.source_sg == null ? null : aws_security_group.this[each.value.source_sg].id

  tags = { Name = each.key }
}

# EN: One "allow all outbound" rule per group (for_each over another resource).
# FR: Une règle « tout sortant autorisé » par groupe (for_each sur une autre ressource).
resource "aws_vpc_security_group_egress_rule" "all" {
  for_each = aws_security_group.this

  security_group_id = each.value.id
  description       = "all-outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
