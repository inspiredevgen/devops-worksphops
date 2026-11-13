# =============================================================================
# azure-web INTEGRATION test (REAL Azure: ~15 min, a few cents; destroyed automatically)
# terraform test -filter=tests/integration.tftest.hcl -verbose   (ARM_* or az login)
# =============================================================================

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

run "setup" {
  module {
    source = "./tests/setup"
  }
}

run "deploy" {
  command = apply

  variables {
    name                = "capit-${run.setup.suffix}"
    environment         = "dev"
    resource_group_name = "rg-tf-capstone-it-${run.setup.suffix}"
    vnet_cidr           = "10.129.0.0/16"
    ssh_public_key      = run.setup.ssh_public_key
    app_version         = "it-${run.setup.suffix}"
    tags                = { Owner = "platform-team", ManagedBy = "terraform-test", Module = "12-capstone" }
  }
}

run "serves_the_page" {
  command = plan

  module {
    source = "./tests/http-check"
  }

  variables {
    url           = run.deploy.url
    expected_text = "Version: it-${run.setup.suffix}"
  }

  assert {
    condition     = output.status_code == 200 && output.contains_expected
    error_message = "The load balancer must serve the new version's page."
  }
}
