output "security_group_ids" {
  description = "EN: { tier => SG ID } / FR: { niveau => ID du SG }"
  value       = { for k, sg in aws_security_group.this : k => sg.id }
}

output "ingress_rule_keys" {
  description = "EN: Flattened rule keys / FR: Clés de règles aplaties"
  value       = sort(keys(local.ingress_rules))
}

output "bucket_name" {
  description = "EN: Bucket with generated lifecycle rules / FR: Compartiment avec règles de cycle de vie générées"
  value       = aws_s3_bucket.data.bucket
}
