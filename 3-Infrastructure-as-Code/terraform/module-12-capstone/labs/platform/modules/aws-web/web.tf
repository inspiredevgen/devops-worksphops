# =============================================================================
# Web tier: internet-facing ALB → Auto Scaling Group of PRIVATE instances (no public IP, no SSH).
# Niveau web : ALB public → groupe Auto Scaling d'instances PRIVÉES (pas d'IP publique, pas de SSH).
# =============================================================================

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  https = var.certificate_arn != null
  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    environment = var.environment
    app_version = var.app_version
  })
}

# ------------------------------------------------------------ security groups
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Load balancer: HTTP/HTTPS from allowed CIDRs"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.name}-alb" }
}

resource "aws_vpc_security_group_ingress_rule" "alb" {
  #checkov:skip=CKV_AWS_260:Public website by design; restrict var.allowed_cidrs for internal apps.
  for_each = { for pair in setproduct(var.allowed_cidrs, local.https ? [80, 443] : [80]) : "${pair[0]}:${pair[1]}" => pair }

  security_group_id = aws_security_group.alb.id
  description       = "Web from ${each.value[0]}"
  cidr_ipv4         = each.value[0]
  ip_protocol       = "tcp"
  from_port         = each.value[1]
  to_port           = each.value[1]
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "To the app instances only"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

resource "aws_security_group" "app" {
  name        = "${var.name}-app"
  description = "App instances: HTTP from the ALB only"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.name}-app" }
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  #checkov:skip=CKV_AWS_260:False positive: the source is the ALB security group, not a CIDR.
  security_group_id            = aws_security_group.app.id
  description                  = "HTTP from the ALB security group only"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

resource "aws_vpc_security_group_egress_rule" "app_https_out" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS out (package repositories, AWS APIs) via NAT"
  #trivy:ignore:AWS-0104 Package repositories have no fixed IPs; tighten with an egress proxy (stretch).
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}

resource "aws_vpc_security_group_egress_rule" "app_http_out" {
  security_group_id = aws_security_group.app.id
  description       = "HTTP out (some package mirrors) via NAT"
  #trivy:ignore:AWS-0104 Package mirrors have no fixed IPs; tighten with an egress proxy (stretch).
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
}

# ------------------------------------------------------------ load balancer
resource "aws_lb" "this" {
  #checkov:skip=CKV_AWS_91:Access logs need a dedicated log bucket; a stretch goal of the capstone.
  #checkov:skip=CKV2_AWS_28:A WAF is a stretch goal (cost); the ALB only accepts HTTP/HTTPS.
  #checkov:skip=CKV_AWS_150:Lab environments must be destroyable; enable deletion protection for real production.
  name                       = "${var.name}-alb"
  load_balancer_type         = "application"
  internal                   = false #trivy:ignore:AVD-AWS-0053 (public web entry point by design)
  security_groups            = [aws_security_group.alb.id]
  subnets                    = [for s in aws_subnet.public : s.id]
  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "app" {
  #checkov:skip=CKV_AWS_378:TLS terminates at the ALB; ALB → instance traffic stays inside the VPC on HTTP.
  name                 = "${var.name}-app"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = aws_vpc.this.id
  deregistration_delay = 30

  health_check {
    path                = "/healthz"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# EN: HTTP is served only without a certificate (no domain); with certificate_arn it redirects to HTTPS.
# FR : HTTP n'est servi que sans certificat (pas de domaine) ; avec certificate_arn, il redirige vers HTTPS.
#trivy:ignore:AWS-0054
resource "aws_lb_listener" "http" {
  #checkov:skip=CKV_AWS_2:HTTP is served only when no certificate is given (no domain in the lab); with certificate_arn it redirects to HTTPS.
  #checkov:skip=CKV_AWS_103:Same as CKV_AWS_2: TLS policy applies to the HTTPS listener.
  #checkov:skip=CKV2_AWS_20:Redirects to HTTPS whenever a certificate is provided.
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = local.https ? "redirect" : "forward"
    target_group_arn = local.https ? null : aws_lb_target_group.app.arn

    dynamic "redirect" {
      for_each = local.https ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
}

resource "aws_lb_listener" "https" {
  count = local.https ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ------------------------------------------------------------ compute
resource "aws_launch_template" "app" {
  name_prefix   = "${var.name}-"
  image_id      = data.aws_ssm_parameter.al2023.insecure_value
  instance_type = var.instance_type
  user_data     = base64encode(local.user_data)

  vpc_security_group_ids = [aws_security_group.app.id]

  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.name}-app" }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = "${var.name}-app" }
  }
}

resource "aws_autoscaling_group" "app" {
  name                      = "${var.name}-app"
  min_size                  = var.min_size
  max_size                  = var.max_size
  vpc_zone_identifier       = [for s in aws_subnet.private : s.id]
  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 180

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  # EN: A new launch template version (e.g. app_version) triggers a refresh. min 100 % / max 200 % =
  #     launch the new instance BEFORE terminating the old one, so even a 1-instance dev has zero downtime.
  # FR : Une nouvelle version du modèle (ex. app_version) déclenche un renouvellement. min 100 % / max 200 % =
  #     lancer la nouvelle instance AVANT d'arrêter l'ancienne : même un dev à 1 instance n'a aucune interruption.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
      max_healthy_percentage = 200
      instance_warmup        = 120
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-app"
    propagate_at_launch = true
  }

  lifecycle {
    precondition {
      condition     = var.min_size <= var.max_size
      error_message = "EN: min_size must be ≤ max_size. / FR : min_size doit être ≤ max_size."
    }

    # EN: Production must survive the loss of an instance AND of an AZ.
    # FR : La production doit survivre à la perte d'une instance ET d'une AZ.
    precondition {
      condition     = var.environment != "prod" || (var.min_size >= 2 && var.nat_gateway_per_az)
      error_message = "EN: prod needs min_size ≥ 2 and nat_gateway_per_az = true. / FR : la prod exige min_size ≥ 2 et nat_gateway_per_az = true."
    }

    # EN: desired_capacity is owned by the scaling policy, not by Terraform.
    # FR : desired_capacity appartient à la politique de mise à l'échelle, pas à Terraform.
    ignore_changes = [desired_capacity]
  }
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.name}-cpu-50"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50
  }
}
