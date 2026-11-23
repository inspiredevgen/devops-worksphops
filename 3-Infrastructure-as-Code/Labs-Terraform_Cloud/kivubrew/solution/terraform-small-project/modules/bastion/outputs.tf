output "public_ip" {
  description = "Public IP of the bastion"
  value       = aws_instance.bastion.public_ip
}

output "security_group_id" {
  description = "Bastion security group, referenced by the web server's SSH rule"
  value       = aws_security_group.bastion.id
}

output "key_name" {
  description = "EC2 key pair name, reused by the web server"
  value       = aws_key_pair.this.key_name
}
