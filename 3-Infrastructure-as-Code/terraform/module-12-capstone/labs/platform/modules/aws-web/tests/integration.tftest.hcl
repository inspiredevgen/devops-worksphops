# =============================================================================
# aws-web INTEGRATION test (REAL AWS: ~10 min, a few cents; destroyed automatically)
# AWS_PROFILE=tf-lab terraform test -filter=tests/integration.tftest.hcl -verbose
# =============================================================================

provider "aws" {
  region = "ca-central-1"

  default_tags {
    tags = {
      Course    = "terraform-cloud-engineer"
      Module    = "12-capstone"
      ManagedBy = "terraform-test"
      Owner     = "platform-team"
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
    name        = "tf-capit-${run.setup.suffix}"
    environment = "dev"
    vpc_cidr    = "10.119.0.0/16"
    app_version = "it-${run.setup.suffix}"
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
    error_message = "The ALB must serve the new version's page."
  }
}

# EN: No separate /healthz check: the ALB only routes to targets whose /healthz returns 200,
#     so a served page already proves the health endpoint works.
# FR : Pas de test /healthz séparé : l'ALB n'achemine que vers les cibles dont /healthz renvoie 200,
#     donc une page servie prouve déjà que le point de santé fonctionne.
