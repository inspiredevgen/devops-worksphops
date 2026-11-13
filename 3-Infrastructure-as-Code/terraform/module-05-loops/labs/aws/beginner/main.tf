# -----------------------------------------------------------------------------
# Lab 5.B-AWS — count: N copies, lists, and conditional resources
# Lab 5.B-AWS — count : N copies, listes et ressources conditionnelles
#
# EN: Empty buckets → $0. force_destroy lets destroy remove them anyway.
# FR: Compartiments vides → 0 $. force_destroy permet quand même de les détruire.
# -----------------------------------------------------------------------------

resource "random_id" "suffix" {
  byte_length = 3
}

# EN: 1) count = a NUMBER → N identical copies. count.index = 0, 1, 2…
#        Addresses: aws_s3_bucket.numbered[0], aws_s3_bucket.numbered[1]…
# FR: 1) count = un NOMBRE → N copies identiques. count.index = 0, 1, 2…
#        Adresses : aws_s3_bucket.numbered[0], aws_s3_bucket.numbered[1]…
resource "aws_s3_bucket" "numbered" {
  count = var.bucket_count

  bucket        = "tf-lab-m05-n${count.index}-${random_id.suffix.hex}"
  force_destroy = true
}

# EN: 2) count over a LIST → one bucket per element, identified by POSITION.
#        ⚠️ Removing "logs" shifts every index → assets/backups get REPLACED.
#        (You'll prove it in the lab, then fix it with for_each.)
# FR: 2) count sur une LISTE → un compartiment par élément, identifié par sa POSITION.
#        ⚠️ Retirer « logs » décale chaque index → assets/backups sont REMPLACÉS.
#        (Vous le prouverez dans le lab, puis le corrigerez avec for_each.)
resource "aws_s3_bucket" "named" {
  count = length(var.bucket_names)

  bucket        = "tf-lab-m05-${var.bucket_names[count.index]}-${random_id.suffix.hex}"
  force_destroy = true
}

# EN: 3) CONDITIONAL resource: count = condition ? 1 : 0
# FR: 3) Ressource CONDITIONNELLE : count = condition ? 1 : 0
resource "aws_s3_bucket" "audit" {
  count = var.create_audit_bucket ? 1 : 0

  bucket        = "tf-lab-m05-audit-${random_id.suffix.hex}"
  force_destroy = true
}
