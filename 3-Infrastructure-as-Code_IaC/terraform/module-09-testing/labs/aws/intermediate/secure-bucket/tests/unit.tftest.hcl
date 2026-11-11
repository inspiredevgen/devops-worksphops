# =============================================================================
# Lab 9.I-AWS — Unit tests for secure-bucket with a MOCKED provider
# Lab 9.I-AWS — Tests unitaires de secure-bucket avec un provider SIMULÉ
# Run from this folder / Lancer depuis ce dossier :  terraform init && terraform test
# EN: mock_provider = no AWS calls, no credentials, no cost, runs in seconds.
# FR : mock_provider = aucun appel AWS, aucun identifiant, aucun coût, quelques secondes.
# =============================================================================

mock_provider "aws" {
  # EN: Mocked data sources return generated values (false for bools). We pin the ones we need.
  # FR : Les sources de données simulées renvoient des valeurs générées (false pour les booléens). On fixe celles qui comptent.
  mock_data "aws_s3_account_public_access_block" {
    defaults = {
      block_public_acls       = true
      block_public_policy     = true
      ignore_public_acls      = true
      restrict_public_buckets = true
    }
  }

  # EN: Computed attributes (unknown until apply) get these values in apply-mode runs.
  # FR : Les attributs calculés (inconnus avant l'apply) reçoivent ces valeurs dans les runs en mode apply.
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::mocked-bucket"
    }
  }
}

# EN: A second mock: an account WITHOUT Block Public Access, to test the check block.
# FR : Une seconde simulation : un compte SANS blocage de l'accès public, pour tester le bloc check.
mock_provider "aws" {
  alias = "open_account"

  mock_data "aws_s3_account_public_access_block" {
    defaults = {
      block_public_acls       = false
      block_public_policy     = false
      ignore_public_acls      = false
      restrict_public_buckets = false
    }
  }
}

variables {
  name        = "tf-unit-test-bucket"
  environment = "dev"
}

# ------------------------------------------------------------ Secure defaults
run "defaults_are_secure" {
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "Versioning must be enabled by default."
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
    error_message = "Without a KMS key, encryption must be SSE-S3 (AES256)."
  }

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.this.block_public_acls,
      aws_s3_bucket_public_access_block.this.block_public_policy,
      aws_s3_bucket_public_access_block.this.ignore_public_acls,
      aws_s3_bucket_public_access_block.this.restrict_public_buckets,
    ])
    error_message = "All four public-access blocks must be on."
  }

  assert {
    condition     = one(aws_s3_bucket_ownership_controls.this.rule).object_ownership == "BucketOwnerEnforced"
    error_message = "ACLs must be disabled (BucketOwnerEnforced)."
  }

  assert {
    condition     = one(one(aws_s3_bucket_lifecycle_configuration.this.rule).noncurrent_version_expiration).noncurrent_days == 30
    error_message = "Old versions must expire after 30 days by default."
  }

  assert {
    condition     = aws_s3_bucket.this.force_destroy == false
    error_message = "force_destroy must default to false."
  }
}

# ------------------------------------------------------------ Behaviour
run "kms_key_switches_algorithm" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:ca-central-1:111122223333:key/11111111-2222-3333-4444-555555555555"
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default).sse_algorithm == "aws:kms"
    error_message = "A KMS key must switch encryption to aws:kms."
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.this.rule).bucket_key_enabled == true
    error_message = "S3 Bucket Keys must be on with KMS (cheaper)."
  }
}

# ------------------------------------------------------------ Guardrails fire
run "rejects_uppercase_name" {
  command = plan

  variables {
    name = "tf-My_Bucket"
  }

  expect_failures = [var.name]
}

run "rejects_fractional_days" {
  command = plan

  variables {
    noncurrent_days = 1.5
  }

  expect_failures = [var.noncurrent_days]
}

run "prod_cannot_force_destroy" {
  command = plan

  variables {
    environment   = "prod"
    force_destroy = true
  }

  expect_failures = [aws_s3_bucket.this]
}

run "warns_when_account_is_open" {
  command = plan

  providers = {
    aws = aws.open_account
  }

  expect_failures = [check.account_blocks_public_access]
}

# ------------------------------------------------------------ Apply with mocks
# EN: command = apply with a mock: "creates" fake resources, so computed values and outputs exist.
# FR : command = apply avec une simulation : « crée » de fausses ressources, donc les valeurs calculées et les sorties existent.
run "outputs_after_apply" {
  command = apply

  assert {
    condition     = output.bucket_arn == "arn:aws:s3:::mocked-bucket"
    error_message = "bucket_arn must come from the bucket resource."
  }

  assert {
    condition     = output.bucket == "tf-unit-test-bucket"
    error_message = "bucket must echo the name."
  }
}

# EN: override_resource: replace ONE resource's values for ONE run.
# FR : override_resource : remplacer les valeurs d'UNE ressource pour UN seul run.
run "override_one_resource" {
  command = apply

  override_resource {
    target = aws_s3_bucket.this
    values = {
      arn = "arn:aws:s3:::overridden"
    }
  }

  assert {
    condition     = output.bucket_arn == "arn:aws:s3:::overridden"
    error_message = "The override must win over the mock defaults."
  }
}
