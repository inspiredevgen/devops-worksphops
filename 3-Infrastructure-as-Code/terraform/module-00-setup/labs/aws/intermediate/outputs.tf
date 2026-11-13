output "role_arn" {
  description = "EN: ARN of the Terraform lab role / FR: ARN du rôle Terraform du cours"
  value       = aws_iam_role.terraform.arn
}

# EN: Paste this block into ~/.aws/config, then `export AWS_PROFILE=tf-lab`.
# FR: Collez ce bloc dans ~/.aws/config, puis `export AWS_PROFILE=tf-lab`.
output "aws_cli_profile_snippet" {
  description = "EN: AWS CLI profile to add to ~/.aws/config / FR: Profil AWS CLI à ajouter dans ~/.aws/config"
  value       = <<-EOT
    [profile tf-lab]
    role_arn       = ${aws_iam_role.terraform.arn}
    source_profile = tf-admin
    region         = ${var.aws_region}
    duration_seconds = ${var.max_session_hours * 3600}
  EOT
}
