output "vpc_id" {
  value = aws_vpc.this.id
}

output "cidr" {
  value = aws_vpc.this.cidr_block
}

output "region" {
  value = data.aws_region.current.region
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}

# EN: Keys are STATIC ("public", "private-0", …) so callers can use them in for_each at plan time.
# FR : Les clés sont STATIQUES (« public », « private-0 », …) pour que l'appelant puisse les utiliser dans for_each au plan.
output "route_table_ids" {
  value = merge(
    { for k, rt in aws_route_table.private : "private-${k}" => rt.id },
    var.public_subnets ? { public = aws_route_table.public[0].id } : {}
  )
}

output "route_table_keys" {
  description = "EN: Known at plan time / FR: Connues au moment du plan"
  value       = concat([for k in keys(local.private) : "private-${k}"], var.public_subnets ? ["public"] : [])
}
