# EN: SPLAT expression [*] → a list of one attribute from every instance.
# FR: Expression SPLAT [*] → la liste d'un attribut de chaque instance.
output "numbered_buckets" {
  description = "EN: Numbered bucket names / FR: Noms des compartiments numérotés"
  value       = aws_s3_bucket.numbered[*].bucket
}

# EN: zipmap(keys, values) pairs the input names with the created buckets.
# FR: zipmap(clés, valeurs) associe les noms d'entrée aux compartiments créés.
output "named_buckets" {
  description = "EN: { short name => bucket } / FR: { nom court => compartiment }"
  value       = zipmap(var.bucket_names, aws_s3_bucket.named[*].bucket)
}

# EN: one() → the single element, or null if the list is empty. Perfect for
#     count = 0/1 resources (indexing [0] would FAIL when count = 0).
# FR: one() → l'unique élément, ou null si la liste est vide. Idéal pour les
#     ressources count = 0/1 (l'index [0] ÉCHOUERAIT quand count = 0).
output "audit_bucket" {
  description = "EN: Audit bucket or null / FR: Compartiment d'audit ou null"
  value       = one(aws_s3_bucket.audit[*].bucket)
}
