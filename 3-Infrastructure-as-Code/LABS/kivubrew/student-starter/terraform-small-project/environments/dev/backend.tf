# HCP Terraform (app.terraform.io) stores the state, locks it and runs Terraform remotely.
# Replace the organization once in Phase 0 (it cannot come from a variable).
terraform {
  cloud {
    organization = "REPLACE_ME_kivubrew-team01"

    workspaces {
      name = "kivubrew-dev"
    }
  }
}
