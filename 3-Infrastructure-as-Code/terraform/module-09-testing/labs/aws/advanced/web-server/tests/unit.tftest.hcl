# =============================================================================
# Lab 9.A-AWS — UNIT tests (mocked, free, seconds)
# Run / Lancer :  terraform test -filter=tests/unit.tftest.hcl
# =============================================================================

mock_provider "aws" {
  mock_data "aws_subnets" {
    defaults = { ids = ["subnet-bbbb", "subnet-aaaa"] }
  }

  mock_data "aws_ssm_parameter" {
    defaults = { insecure_value = "ami-0123456789abcdef0" }
  }

  mock_resource "aws_instance" {
    defaults = { public_ip = "203.0.113.10" }
  }
}

variables {
  name         = "tf-unit-web"
  allowed_cidr = "198.51.100.7/32"
  message      = "unit-test-message"
}

run "hardened_instance" {
  command = plan

  assert {
    condition     = aws_instance.this.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be required."
  }

  assert {
    condition     = aws_instance.this.root_block_device[0].encrypted
    error_message = "The root volume must be encrypted."
  }

  assert {
    condition     = aws_instance.this.subnet_id == "subnet-aaaa"
    error_message = "Subnet choice must be deterministic (sorted)."
  }
}

run "only_allowed_cidr_on_port_80" {
  command = plan

  assert {
    condition     = aws_vpc_security_group_ingress_rule.http.cidr_ipv4 == "198.51.100.7/32"
    error_message = "Ingress must be limited to allowed_cidr."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.http.from_port == 80 && aws_vpc_security_group_ingress_rule.http.to_port == 80
    error_message = "Only port 80 may be open."
  }
}

run "message_reaches_the_page" {
  command = plan

  assert {
    condition     = strcontains(output.rendered_user_data, "<p>unit-test-message</p>")
    error_message = "The message must be rendered into the page."
  }

  assert {
    condition     = strcontains(output.rendered_user_data, "$${INSTANCE_ID}")
    error_message = "Bash variables must survive templating as $${…}."
  }
}

run "refuses_the_whole_internet" {
  command = plan

  variables {
    allowed_cidr = "0.0.0.0/0"
  }

  expect_failures = [var.allowed_cidr]
}

run "url_after_apply" {
  command = apply

  assert {
    condition     = output.url == "http://203.0.113.10"
    error_message = "url must use the instance's public IP."
  }
}
