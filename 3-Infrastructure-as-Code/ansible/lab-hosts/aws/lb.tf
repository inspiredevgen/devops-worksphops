# =============================================================================
# load_balancer = true: an Application Load Balancer in front of every host with role "web".
#   Health check GET /healthz every 5 s; a target is out after 2 failures, back after 2 successes.
#   Deregistration delay 15 s (production: 60–300 s) so the rolling-update lab drains quickly.
# load_balancer = true : un Application Load Balancer devant chaque hôte de rôle « web ».
# =============================================================================
locals {
  lb       = var.load_balancer
  web_keys = [for k, h in var.hosts : k if h.role == "web"]
}

data "aws_subnets" "default" {
  count = local.lb ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

resource "aws_security_group" "alb" {
  count = local.lb ? 1 : 0

  name        = "ans-lab-alb-${random_id.suffix.hex}"
  description = "Ansible lab ALB"
  vpc_id      = data.aws_vpc.default.id
  tags        = { Name = "ans-lab-alb-${random_id.suffix.hex}" }

  lifecycle {
    precondition {
      condition     = local.ssh && var.my_ip != null
      error_message = "EN: load_balancer needs access = \"ssh\" and my_ip. / FR : load_balancer exige access = « ssh » et my_ip."
    }
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  count = local.lb ? 1 : 0

  security_group_id = aws_security_group.alb[0].id
  description       = "HTTP to the ALB from the control node only"
  cidr_ipv4         = "${var.my_ip}/32"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_to_hosts" {
  count = local.lb ? 1 : 0

  security_group_id            = aws_security_group.alb[0].id
  description                  = "HTTP to the lab hosts"
  referenced_security_group_id = aws_security_group.lab.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

resource "aws_vpc_security_group_ingress_rule" "hosts_from_alb" {
  count = local.lb ? 1 : 0

  security_group_id            = aws_security_group.lab.id
  description                  = "HTTP from the ALB (traffic + health checks)"
  referenced_security_group_id = aws_security_group.alb[0].id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}


resource "aws_lb" "web" {
  count = local.lb ? 1 : 0

  name                       = "ans-lab-${random_id.suffix.hex}"
  load_balancer_type         = "application"
  internal                   = false
  security_groups            = [aws_security_group.alb[0].id]
  subnets                    = data.aws_subnets.default[0].ids
  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "web" {
  count = local.lb ? 1 : 0

  # EN: A FIXED name: the Ansible playbook finds it by name (community.aws.elb_target target_group_name).
  # FR : Un nom FIXE : le playbook Ansible le trouve par son nom.
  name                 = "ans-lab-web"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = data.aws_vpc.default.id
  deregistration_delay = 15

  health_check {
    path                = "/healthz"
    matcher             = "200"
    interval            = 5
    timeout             = 2
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "web" {
  for_each = local.lb ? toset(local.web_keys) : toset([])

  target_group_arn = aws_lb_target_group.web[0].arn
  target_id        = aws_instance.host[each.key].id
  port             = 80
}

resource "aws_lb_listener" "http" {
  count = local.lb ? 1 : 0

  load_balancer_arn = aws_lb.web[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web[0].arn
  }
}
