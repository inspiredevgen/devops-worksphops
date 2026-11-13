# Changelog — terraform-aws-network

🇬🇧 All notable changes. Format: [Keep a Changelog](https://keepachangelog.com) · Versioning: [SemVer](https://semver.org).
🇫🇷 Tous les changements notables. Format : [Keep a Changelog](https://keepachangelog.com) · Versionnage : [SemVer](https://semver.org).

## [2.0.0]

### ⚠ BREAKING CHANGES / CHANGEMENTS INCOMPATIBLES
- Input `cidr_block` renamed to `vpc_cidr`. **Callers must update their module block.**
- L'entrée `cidr_block` est renommée `vpc_cidr`. **Les appelants doivent modifier leur bloc module.**

### Changed / Modifié
- Internal: `aws_vpc.this` → `aws_vpc.main`. A `moved` block is included: **no resource is replaced** on upgrade.
- Interne : `aws_vpc.this` → `aws_vpc.main`. Un bloc `moved` est inclus : **aucune ressource n'est remplacée** à la mise à niveau.

### Upgrade guide / Guide de mise à niveau
```diff
 module "network" {
-  source     = "git::https://github.com/<YOU>/terraform-aws-network.git?ref=v1.1.0"
-  cidr_block = "10.60.0.0/16"
+  source     = "git::https://github.com/<YOU>/terraform-aws-network.git?ref=v2.0.0"
+  vpc_cidr   = "10.60.0.0/16"
 }
```
Then / Puis : `terraform init -upgrade && terraform plan` → expect / attendu : `has moved to`, `0 to destroy`.

## [1.1.0]

### Added / Ajouté
- `enable_s3_endpoint` (default `false`): optional, free S3 gateway endpoint.
- `enable_s3_endpoint` (par défaut `false`) : point de terminaison passerelle S3 optionnel et gratuit.
- Output / Sortie `s3_endpoint_id`.

## [1.0.0]

### Added / Ajouté
- VPC, Internet Gateway, public + private subnets in 1–3 AZs, route tables.
- VPC, passerelle Internet, sous-réseaux publics + privés sur 1 à 3 zones, tables de routage.
