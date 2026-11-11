# =============================================================================
# Lab 9.A-AZ — UNIT tests (mocked, free, seconds)
# Run / Lancer :  terraform test -filter=tests/unit.tftest.hcl
# =============================================================================

mock_provider "azurerm" {
  mock_resource "azurerm_public_ip" {
    defaults = { ip_address = "203.0.113.20" }
  }
}

variables {
  name           = "unit-web"
  allowed_cidr   = "198.51.100.7/32"
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIUnitTestKeyOnly unit@test"
  message        = "unit-test-message"
}

run "hardened_vm" {
  command = plan

  assert {
    condition     = azurerm_linux_virtual_machine.this.disable_password_authentication
    error_message = "Password login must be disabled."
  }

  assert {
    condition     = azurerm_linux_virtual_machine.this.size == "Standard_B1s"
    error_message = "Default size must stay the cheap B1s."
  }
}

run "only_allowed_cidr_on_port_80" {
  command = plan

  assert {
    condition     = one(azurerm_network_security_group.this.security_rule).source_address_prefix == "198.51.100.7/32"
    error_message = "Inbound HTTP must be limited to allowed_cidr."
  }

  assert {
    condition     = one(azurerm_network_security_group.this.security_rule).destination_port_range == "80"
    error_message = "Only port 80 may be open."
  }
}

run "cloud_init_is_valid_and_has_message" {
  command = plan

  assert {
    condition     = startswith(output.rendered_cloud_init, "#cloud-config")
    error_message = "cloud-init needs the #cloud-config header on line 1."
  }

  assert {
    condition     = can(yamldecode(output.rendered_cloud_init))
    error_message = "The rendered document must be valid YAML."
  }

  assert {
    condition     = contains(yamldecode(output.rendered_cloud_init).packages, "nginx")
    error_message = "nginx must be installed."
  }

  assert {
    condition     = strcontains(output.rendered_cloud_init, "<p>unit-test-message</p>")
    error_message = "The message must be rendered into the page."
  }
}

run "refuses_the_whole_internet" {
  command = plan

  variables {
    allowed_cidr = "0.0.0.0/0"
  }

  expect_failures = [var.allowed_cidr]
}

run "refuses_a_key_path" {
  command = plan

  variables {
    ssh_public_key = "~/.ssh/id_rsa.pub"
  }

  expect_failures = [var.ssh_public_key]
}

run "url_after_apply" {
  command = apply

  assert {
    condition     = output.url == "http://203.0.113.20"
    error_message = "url must use the public IP."
  }
}
