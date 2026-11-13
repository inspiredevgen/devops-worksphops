output "state_bucket" {
  description = "EN: State bucket name / FR: Nom du compartiment d'état"
  value       = aws_s3_bucket.state.bucket
}

# EN: A PARTIAL backend configuration, shared by every configuration that
#     stores state here. Each one adds its own unique `key` at init time.
#     Save it with: terraform output -raw backend_hcl > ../backend.hcl
# FR: Une configuration de backend PARTIELLE, partagée par toutes les
#     configurations qui stockent leur état ici. Chacune ajoute sa propre `key`
#     unique lors de l'init. Enregistrez-la avec :
#     terraform output -raw backend_hcl > ../backend.hcl
output "backend_hcl" {
  description = "EN: Partial backend config / FR: Configuration de backend partielle"
  value       = <<-EOT
    bucket       = "${aws_s3_bucket.state.bucket}"
    region       = "${var.aws_region}"
    encrypt      = true
    use_lockfile = true
  EOT
}
