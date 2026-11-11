# =============================================================================
# Lab 9.A-AWS — INTEGRATION tests (REAL AWS: ~10 min, ~1 cent)
# Run / Lancer :  AWS_PROFILE=tf-lab terraform test -filter=tests/integration.tftest.hcl
# EN: Real resources are created, checked, then DESTROYED automatically by terraform test.
# FR : De vraies ressources sont créées, vérifiées, puis DÉTRUITES automatiquement par terraform test.
# =============================================================================

provider "aws" {
  region = "ca-central-1"

  default_tags {
    tags = {
      Course    = "terraform-cloud-engineer"
      Module    = "09-testing"
      ManagedBy = "terraform-test"
    }
  }
}

# EN: 1. A helper module: unique suffix + the runner's public IP.
# FR : 1. Un module d'aide : suffixe unique + IP publique de l'exécuteur.
run "setup" {
  module {
    source = "./tests/setup"
  }
}

# EN: 2. Deploy the module under test, for real.
# FR : 2. Déployer réellement le module testé.
run "deploy" {
  command = apply

  variables {
    name         = "tf-m09-it-${run.setup.suffix}"
    allowed_cidr = "${run.setup.my_ip}/32"
    message      = "integration-${run.setup.suffix}"
  }

  assert {
    condition     = can(regex("^http://[0-9.]+$", output.url))
    error_message = "url must be http://<public IP>."
  }
}

# EN: 3. Check BEHAVIOUR from the outside: the page answers and shows our message.
# FR : 3. Vérifier le COMPORTEMENT depuis l'extérieur : la page répond et affiche notre message.
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
