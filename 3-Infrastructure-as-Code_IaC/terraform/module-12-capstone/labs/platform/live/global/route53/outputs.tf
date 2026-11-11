output "url" {
  value = "http://${local.fqdn}"
}

output "health_check_status_commands" {
  value = {
    aws   = "aws route53 get-health-check-status --health-check-id ${aws_route53_health_check.aws.id} --query 'HealthCheckObservations[].StatusReport.Status' --output text"
    azure = "aws route53 get-health-check-status --health-check-id ${aws_route53_health_check.azure.id} --query 'HealthCheckObservations[].StatusReport.Status' --output text"
  }
}
