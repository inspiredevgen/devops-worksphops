# =============================================================================
# scale_set != null: an Auto Scaling group of Ubuntu web servers (Module 7, day-2 operations).
#   Instances are tagged like the other lab hosts EXCEPT Host (they come and go): the dynamic inventory names them
#   by instance ID and groups them by the aws:autoscaling:groupName tag.
# scale_set != null : un groupe Auto Scaling de serveurs web Ubuntu (module 7, opérations de jour 2).
# =============================================================================
locals {
  asg = var.scale_set != null
}

data "aws_subnets" "asg" {
  count = local.asg ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

resource "aws_launch_template" "web" {
  count = local.asg ? 1 : 0

  name_prefix   = "ans-lab-web-"
  image_id      = data.aws_ssm_parameter.ami["ubuntu"].insecure_value
  instance_type = var.instance_type
  key_name      = aws_key_pair.lab[0].key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.lab.id]
  }

  metadata_options {
    http_tokens            = "required"
    instance_metadata_tags = "enabled"
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      encrypted   = true
      volume_type = "gp3"
    }
  }

  lifecycle {
    precondition {
      condition     = local.ssh && var.my_ip != null
      error_message = "EN: scale_set needs access = \"ssh\" and my_ip. / FR : scale_set exige access = « ssh » et my_ip."
    }
  }
}

resource "aws_autoscaling_group" "web" {
  count = local.asg ? 1 : 0

  name                = "ans-lab-web-asg"
  min_size            = 0
  max_size            = var.scale_set.max
  desired_capacity    = var.scale_set.capacity
  vpc_zone_identifier = data.aws_subnets.asg[0].ids
  health_check_type   = "EC2"

  launch_template {
    id      = aws_launch_template.web[0].id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = {
      Name        = "ans-lab-asg-web"
      Course      = "ansible-cloud-engineer"
      Module      = var.module_tag
      ManagedBy   = "terraform"
      Role        = "web"
      Environment = "dev"
      OS          = "ubuntu"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  # EN: Day-2 scaling is Ansible's job: Terraform must not "fix" the capacity back on the next apply.
  # FR : La mise à l'échelle de jour 2 revient à Ansible : Terraform ne doit pas « corriger » la capacité au prochain apply.
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
