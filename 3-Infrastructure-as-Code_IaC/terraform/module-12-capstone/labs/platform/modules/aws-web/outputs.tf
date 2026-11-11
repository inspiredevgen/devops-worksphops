output "url" {
  description = "EN: Public URL / FR: URL publique"
  value       = "${local.https ? "https" : "http"}://${aws_lb.this.dns_name}"
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "EN: For Route 53 alias records / FR: Pour les enregistrements alias Route 53"
  value       = aws_lb.this.zone_id
}

output "asg_name" {
  value = aws_autoscaling_group.app.name
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "rendered_user_data" {
  description = "EN: For tests / FR: Pour les tests"
  value       = local.user_data
}
