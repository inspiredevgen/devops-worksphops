# OWNER: Compute owner
#
# TODO — build these resources:
#   1. data "aws_ssm_parameter" — Amazon Linux 2023 AMI (same path as the bastion module)
#   2. aws_security_group "web" — name_prefix, create_before_destroy
#   3. Ingress HTTP 80/tcp      — one rule per CIDR in var.allowed_http_cidrs
#   4. Ingress SSH 22/tcp       — ONLY from var.bastion_security_group_id
#                                 (hint: referenced_security_group_id, not cidr_ipv4)
#   5. Egress all
#   6. aws_instance "web"
#        - key_name = var.key_name, public IP, IMDSv2, encrypted gp3
#        - user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", { ... })
#          the template needs: app_repo_url, app_version, app_source_dir, environment, aws_region
#        - user_data_replace_on_change = true   <-- this IS the deployment mechanism. Explain why in your PR.
#        - tags include AppVersion = var.app_version
#        - lifecycle ignore_changes = [ami]
#   7. aws_eip "web" — only when var.enable_eip is true (count = var.enable_eip ? 1 : 0)
#   8. locals { public_ip = <EIP address if enabled, otherwise instance public IP> }
