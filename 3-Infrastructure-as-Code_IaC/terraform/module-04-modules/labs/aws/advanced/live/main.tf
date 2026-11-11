# -----------------------------------------------------------------------------
# Lab 4.A-AWS — Composition with a VERSIONED module from Git
# Lab 4.A-AWS — Composition avec un module VERSIONNÉ depuis Git
#
# EN: STARTING POINT (network v1.0.0). The guide walks you through upgrading
#     to v1.1.0 (new feature) and v2.0.0 (breaking change). Final version:
#     ../solution/main.tf.v2.solution. Cost: $0.
# FR: POINT DE DÉPART (network v1.0.0). Le guide vous accompagne vers la
#     v1.1.0 (nouvelle fonctionnalité) et la v2.0.0 (changement incompatible).
#     Version finale : ../solution/main.tf.v2.solution. Coût : 0 $.
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

# EN: FLAT COMPOSITION — the ROOT wires modules together: outputs of one
#     module become inputs of another. Modules never call each other here.
# FR: COMPOSITION À PLAT — la RACINE relie les modules : les sorties de l'un
#     deviennent les entrées de l'autre. Ici, les modules ne s'appellent pas entre eux.

module "network" {
  # EN: Replace <YOUR-GITHUB-USER>. Without GitHub, use a local repo:
  #       source = "git::file:///ABSOLUTE/PATH/terraform-aws-network?ref=v1.0.0"
  #     `?ref=` pins a TAG (or branch/commit). Never point at a moving branch in prod.
  # FR: Remplacez <YOUR-GITHUB-USER>. Sans GitHub, utilisez un dépôt local :
  #       source = "git::file:///CHEMIN/ABSOLU/terraform-aws-network?ref=v1.0.0"
  #     `?ref=` épingle une ÉTIQUETTE (ou branche/commit). Jamais une branche mouvante en prod.
  source = "git::https://github.com/<YOUR-GITHUB-USER>/terraform-aws-network.git?ref=v1.0.0"

  name       = "tf-lab-m04-platform"
  cidr_block = "10.62.0.0/16"
  az_count   = 2
}

module "data_bucket" {
  source = "./modules/private-bucket"

  name_prefix = "tf-lab-m04-data"

  # EN: v1.0.0 has no S3 endpoint yet → no restriction.
  # FR: La v1.0.0 n'a pas encore de point de terminaison S3 → aucune restriction.
  restrict_to_vpc_endpoint = false
}

output "vpc_id" {
  description = "EN: VPC ID / FR: ID du VPC"
  value       = module.network.vpc_id
}

output "bucket_name" {
  description = "EN: Data bucket / FR: Compartiment de données"
  value       = module.data_bucket.bucket_name
}
