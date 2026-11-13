# =============================================================================
# Lab 9.A-AZ — INTEGRATION tests (REAL Azure: ~10-15 min, ~2 cents)
# Run / Lancer :  terraform test -filter=tests/integration.tftest.hcl   (ARM_* set)
# =============================================================================

provider "azurerm" {
  features {
    resource_group {
      # EN: Tests must always clean up, even if something extra was created.
      # FR : Les tests doivent toujours nettoyer, même si quelque chose de plus a été créé.
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
    name           = "it-${run.setup.suffix}"
    allowed_cidr   = "${run.setup.my_ip}/32"
    ssh_public_key = run.setup.ssh_public_key
    message        = "integration-${run.setup.suffix}"
  }

  assert {
    condition     = can(regex("^http://[0-9.]+$", output.url))
    error_message = "url must be http://<public IP>."
  }
}

run "serves_the_page" {
  command = plan

  module {
    source = "./tests/http-check"
  }

  variables {
    url           = run.deploy.url
    expected_text = "integration-${run.setup.suffix}"
  }

  assert {
    condition     = output.status_code == 200
    error_message = "Expected HTTP 200 from ${run.deploy.url}."
  }

  assert {
    condition     = output.contains_expected
    error_message = "The page does not contain the expected message."
  }
}
