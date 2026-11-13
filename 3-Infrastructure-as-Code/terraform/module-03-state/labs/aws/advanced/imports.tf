# -----------------------------------------------------------------------------
# EN: IMPORT BLOCKS (Terraform ≥ 1.5): declarative, reviewable in a PR, and
#     shown in `terraform plan` BEFORE anything is written to state.
#     `id` is the provider-specific import ID (see each resource's docs).
#     Delete this file after a successful import (step 3) — imports are a
#     one-time operation; Git history keeps the audit trail.
# FR: BLOCS IMPORT (Terraform ≥ 1.5) : déclaratifs, révisables en PR, et
#     affichés dans `terraform plan` AVANT toute écriture dans l'état.
#     `id` est l'ID d'import propre au provider (voir la doc de chaque ressource).
#     Supprimez ce fichier après un import réussi (étape 3) — l'import est une
#     opération ponctuelle ; l'historique Git garde la trace.
# -----------------------------------------------------------------------------

import {
  to = aws_s3_bucket.legacy
  id = var.legacy_bucket_name
}

import {
  to = aws_s3_bucket_versioning.legacy
  id = var.legacy_bucket_name
}

import {
  to = aws_ssm_parameter.legacy
  id = "/tf-lab/m03/legacy-config"
}

# EN: No resource block exists for this address → run
#       terraform plan -generate-config-out=generated_sg.tf
#     and Terraform writes the HCL for you.
# FR: Aucun bloc de ressource n'existe pour cette adresse → exécutez
#       terraform plan -generate-config-out=generated_sg.tf
#     et Terraform écrit le HCL pour vous.
import {
  to = aws_security_group.legacy
  id = var.legacy_sg_id
}
