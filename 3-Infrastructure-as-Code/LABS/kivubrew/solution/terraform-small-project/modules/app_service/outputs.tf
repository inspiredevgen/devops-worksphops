output "instance_id" {
  description = "ID of the web server instance"
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Public IP of the site (Elastic IP when enabled)"
  value       = local.public_ip
}

output "private_ip" {
  description = "Private IP of the web server (SSH target behind the bastion)"
  value       = aws_instance.web.private_ip
}

output "app_url" {
  description = "URL to open in a browser (plain HTTP, no DNS)"
  value       = "http://${local.public_ip}"
}

output "security_group_id" {
  description = "ID of the web security group"
  value       = aws_security_group.web.id
}
