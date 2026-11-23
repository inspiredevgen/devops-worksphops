aws_region  = "ca-central-1"
team        = "team01" # TODO: your team number
environment = "dev"

vpc_cidr            = "10.10.0.0/16"
public_subnet_cidrs = ["10.10.1.0/24", "10.10.2.0/24"]

instance_type = "t3.micro"

# Every team member's IP: curl -s https://checkip.amazonaws.com
allowed_ssh_cidrs = ["203.0.113.10/32"] # TODO
# ssh_public_key is NOT here: it is set as a workspace variable in HCP Terraform

app_repo_url = "https://github.com/YOUR_ORG/static-web-app.git" # TODO
app_version  = "main" # DEV follows the main branch

enable_eip = false # DEV: the IP may change, that's fine
