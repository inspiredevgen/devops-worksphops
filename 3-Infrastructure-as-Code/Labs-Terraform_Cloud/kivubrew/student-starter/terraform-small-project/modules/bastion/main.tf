# OWNER: Network owner
#
# TODO — build these resources:
#   1. data "aws_ssm_parameter" — Amazon Linux 2023 AMI:
#        /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64
#      (Why not a hard-coded AMI ID? DEV and PROD are in DIFFERENT regions.)
#   2. aws_key_pair          — key_name_prefix = "${var.name_prefix}-", public_key = var.public_key
#   3. aws_security_group    — name_prefix, in var.vpc_id, create_before_destroy
#   4. aws_vpc_security_group_ingress_rule — port 22/tcp, one rule PER CIDR in var.allowed_ssh_cidrs (for_each)
#   5. aws_vpc_security_group_egress_rule  — all outbound
#   6. aws_instance "bastion" — in var.subnet_id, public IP, key pair above, IMDSv2 required,
#                               encrypted gp3 root volume, lifecycle ignore_changes = [ami]
#
# Question to answer in your PR: why does variables.tf REJECT 0.0.0.0/0 for SSH?
