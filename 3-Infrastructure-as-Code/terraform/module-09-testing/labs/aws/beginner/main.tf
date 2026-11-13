# =============================================================================
# Lab 9.B-AWS — Guardrails in code, then static analysis
# Lab 9.B-AWS — Des garde-fous dans le code, puis l'analyse statique
# =============================================================================

resource "random_id" "suffix" {
  byte_length = 3
}

module "bucket" {
  source = "./modules/secure-bucket"

  name          = "tf-lab-m09-${random_id.suffix.hex}"
  environment   = var.environment
  force_destroy = var.force_destroy
}

output "bucket" {
  value = module.bucket.bucket
}
