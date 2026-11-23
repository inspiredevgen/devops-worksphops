# Backend blocks cannot use variables. Replace the two placeholders once (Phase 0).
# The state bucket lives in ca-central-1 for BOTH environments — the backend region
# is where the STATE is stored, not where the resources are deployed.
terraform {
  backend "s3" {
    bucket       = "REPLACE_ME_state_bucket" # output of bootstrap/: state_bucket_name
    key          = "REPLACE_ME_teamXX/dev/terraform.tfstate"
    region       = "ca-central-1"
    encrypt      = true
    use_lockfile = true # S3-native locking (Terraform >= 1.10), no DynamoDB table needed
  }
}
