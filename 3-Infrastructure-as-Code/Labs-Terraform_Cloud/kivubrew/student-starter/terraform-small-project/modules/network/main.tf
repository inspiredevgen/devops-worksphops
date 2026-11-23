# OWNER: Network owner
# Contract: inputs are fixed in variables.tf, outputs required in outputs.tf.
#
# TODO — build these resources:
#   1. data "aws_availability_zones"  — look up AZs (never hard-code "ca-central-1a")
#   2. aws_vpc                        — var.vpc_cidr, DNS support + DNS hostnames ON
#   3. aws_internet_gateway           — attached to the VPC
#   4. aws_subnet "public"            — ONE per entry in var.public_subnet_cidrs (count),
#                                       each in a different AZ, map_public_ip_on_launch = true
#   5. aws_route_table "public"       — default route 0.0.0.0/0 -> internet gateway
#   6. aws_route_table_association    — every public subnet -> public route table
#
# Every resource gets: tags = { Name = "${var.name_prefix}-<something>" }
# Other tags (Project, Team, Environment) come from provider default_tags — don't repeat them.
