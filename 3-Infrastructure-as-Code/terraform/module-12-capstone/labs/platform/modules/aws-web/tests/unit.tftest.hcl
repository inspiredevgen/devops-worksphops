# =============================================================================
# aws-web UNIT tests (mocked AWS: free, seconds) — terraform test -filter=tests/unit.tftest.hcl
# Tests UNITAIRES d'aws-web (AWS simulé : gratuit, quelques secondes)
# =============================================================================

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["ca-central-1a", "ca-central-1b", "ca-central-1d"] }
  }

  mock_data "aws_region" {
    defaults = { region = "ca-central-1" }
  }

  mock_data "aws_ssm_parameter" {
    defaults = { insecure_value = "ami-0123456789abcdef0" }
  }

  mock_resource "aws_lb" {
    defaults = { dns_name = "tf-cap-unit-alb-123.ca-central-1.elb.amazonaws.com" }
  }
}

variables {
  name        = "tf-cap-unit"
  environment = "dev"
  vpc_cidr    = "10.110.0.0/16"
}

run "dev_shape" {
  command = plan

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.private) == 2
    error_message = "Two AZs by default: 2 public + 2 private subnets."
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "dev shares ONE NAT gateway."
  }

  assert {
    condition     = aws_subnet.private["ca-central-1a"].cidr_block == "10.110.128.0/20"
    error_message = "Private subnets start at netnum 8 (/20)."
  }
}

run "prod_shape" {
  command = plan

  variables {
    environment        = "prod"
    nat_gateway_per_az = true
    min_size           = 2
    max_size           = 4
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 2
    error_message = "prod has one NAT gateway per AZ."
  }
}

run "hardened_instances" {
  command = plan

  assert {
    condition     = aws_launch_template.app.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be required."
  }

  assert {
    condition     = one(aws_launch_template.app.block_device_mappings).ebs[0].encrypted == "true"
    error_message = "Root volumes must be encrypted."
  }

  assert {
    condition     = aws_lb.this.drop_invalid_header_fields
    error_message = "The ALB must drop invalid HTTP headers."
  }

  assert {
    condition     = aws_autoscaling_group.app.instance_refresh[0].preferences[0].min_healthy_percentage == 100 && aws_autoscaling_group.app.instance_refresh[0].preferences[0].max_healthy_percentage == 200
    error_message = "Deploys must launch new instances before terminating old ones."
  }
}

run "network_paths" {
  command = apply # EN: mocked apply: IDs exist, so we can compare them / FR : apply simulé : les ID existent

  assert {
    condition     = aws_vpc_security_group_ingress_rule.app_from_alb.referenced_security_group_id == aws_security_group.alb.id
    error_message = "Instances accept traffic ONLY from the ALB security group."
  }

  assert {
    condition     = toset(aws_autoscaling_group.app.vpc_zone_identifier) == toset([for s in aws_subnet.private : s.id])
    error_message = "Instances must live in the PRIVATE subnets."
  }

  assert {
    condition     = output.url == "http://tf-cap-unit-alb-123.ca-central-1.elb.amazonaws.com"
    error_message = "Without a certificate the URL is http://<alb dns>."
  }
}

run "https_when_certificate" {
  command = plan

  variables {
    certificate_arn = "arn:aws:acm:ca-central-1:111122223333:certificate/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = length(aws_lb_listener.https) == 1 && aws_lb_listener.http.default_action[0].type == "redirect"
    error_message = "A certificate adds HTTPS and turns HTTP into a redirect."
  }
}

run "page_content" {
  command = plan

  variables {
    app_version = "9.9.9"
  }

  assert {
    condition     = strcontains(output.rendered_user_data, "Version: 9.9.9") && strcontains(output.rendered_user_data, "Cloud: AWS")
    error_message = "The page must show the cloud and the version."
  }

  assert {
    condition     = aws_launch_template.app.user_data == base64encode(output.rendered_user_data)
    error_message = "The launch template must carry the rendered script."
  }
}

run "prod_requires_ha" {
  command = plan

  variables {
    environment = "prod"
  }

  expect_failures = [aws_autoscaling_group.app]
}

run "rejects_long_names" {
  command = plan

  variables {
    name = "tf-this-name-is-far-too-long-for-an-alb"
  }

  expect_failures = [var.name]
}

run "rejects_unsafe_versions" {
  command = plan

  variables {
    app_version = "1.0'; rm -rf /"
  }

  expect_failures = [var.app_version]
}
