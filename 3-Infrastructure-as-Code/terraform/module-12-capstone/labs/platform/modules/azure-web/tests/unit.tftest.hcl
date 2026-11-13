# =============================================================================
# azure-web UNIT tests (mocked Azure: free, seconds) — terraform test -filter=tests/unit.tftest.hcl
# Tests UNITAIRES d'azure-web (Azure simulé : gratuit, quelques secondes)
# =============================================================================

mock_provider "azurerm" {
  mock_resource "azurerm_public_ip" {
    defaults = {
      fqdn       = "tfcap-dev-abc123.canadacentral.cloudapp.azure.com"
      ip_address = "203.0.113.30"
    }
  }

  mock_data "azurerm_resource_group" {
    defaults = {
      name     = "rg-tf-cicd-dev"
      location = "canadacentral"
    }
  }
}

variables {
  name                = "capstone-unit"
  environment         = "dev"
  resource_group_name = "rg-tf-capstone-unit"
  vnet_cidr           = "10.120.0.0/16"
  ssh_public_key      = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIUnitTestKeyOnly unit@test"
  tags                = { Owner = "platform-team" }
}

run "zero_downtime_and_self_healing" {
  command = plan

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.app.upgrade_mode == "Rolling"
    error_message = "Rolling upgrades: new versions roll out in batches."
  }

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.app.automatic_instance_repair[0].enabled
    error_message = "Unhealthy instances must be repaired automatically."
  }

  assert {
    condition     = toset(azurerm_linux_virtual_machine_scale_set.app.zones) == toset(["1", "2", "3"])
    error_message = "Instances spread over three zones by default."
  }
}

run "hardened" {
  command = plan

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.app.disable_password_authentication
    error_message = "No password logins."
  }

  assert {
    condition     = contains([for r in azurerm_network_security_group.app.security_rule : r.name if r.access == "Deny" && r.priority == 4000], "deny-everything-else")
    error_message = "The NSG must end with an explicit deny."
  }

  assert {
    condition     = azurerm_lb_rule.http.disable_outbound_snat
    error_message = "Outbound traffic must use the explicit outbound rule."
  }

  assert {
    condition     = azurerm_lb_probe.http.request_path == "/healthz"
    error_message = "The probe checks /healthz."
  }
}

run "cloud_init" {
  command = plan

  variables {
    app_version = "9.9.9"
  }

  assert {
    condition     = can(yamldecode(output.rendered_cloud_init)) && contains(yamldecode(output.rendered_cloud_init).packages, "nginx")
    error_message = "cloud-init must be valid YAML and install nginx."
  }

  assert {
    condition     = strcontains(output.rendered_cloud_init, "Cloud: Azure") && strcontains(output.render_command, "render.sh '9.9.9'")
    error_message = "The page template shows the cloud; the extension renders THIS version."
  }

  assert {
    condition     = one(azurerm_linux_virtual_machine_scale_set.app.extension).force_update_tag == "9.9.9"
    error_message = "A new app_version must re-run the render extension."
  }
}

run "existing_resource_group" {
  command = plan

  variables {
    create_resource_group = false
    resource_group_name   = "rg-tf-cicd-dev"
  }

  assert {
    condition     = length(azurerm_resource_group.this) == 0 && azurerm_virtual_network.this.resource_group_name == "rg-tf-cicd-dev"
    error_message = "With create_resource_group = false, the module must USE the existing group."
  }
}

run "outputs_after_apply" {
  command = apply

  assert {
    condition     = output.url == "http://tfcap-dev-abc123.canadacentral.cloudapp.azure.com" && output.public_ip == "203.0.113.30"
    error_message = "Outputs must expose the FQDN and the IP for the global layer."
  }
}

run "prod_requires_ha" {
  command = plan

  variables {
    environment = "prod"
  }

  expect_failures = [azurerm_linux_virtual_machine_scale_set.app]
}

run "tags_need_owner" {
  command = plan

  variables {
    tags = { Course = "x" }
  }

  expect_failures = [var.tags]
}

run "rejects_unsafe_versions" {
  command = plan

  variables {
    app_version = "1.0'; rm -rf /"
  }

  expect_failures = [var.app_version]
}
