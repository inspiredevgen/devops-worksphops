aws_region  = "us-east-1"
team        = "team01" # TODO: your team number
environment = "prod"

vpc_cidr            = "10.20.0.0/16" # never overlaps DEV (future VPC peering)
public_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24"]

instance_type = "t3.micro"

# PROD: only the Release Manager's IP (least privilege)
allowed_ssh_cidrs = ["203.0.113.20/32"] # TODO
# ssh_public_key is NOT here: it is set as a workspace variable in HCP Terraform

app_repo_url = "https://github.com/YOUR_ORG/static-web-app.git" # TODO
app_version  = "v1.0.0" # PROD is ALWAYS pinned to a release tag — never "main"

enable_eip = true # PROD: stable public IP for customers (no DNS)
