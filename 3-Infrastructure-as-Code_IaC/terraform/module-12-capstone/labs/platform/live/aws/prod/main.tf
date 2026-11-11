# =============================================================================
# Capstone · AWS · prod
# =============================================================================

module "web" {
  source = "../../../modules/aws-web"

  name               = "tf-capstone-prod"
  environment        = "prod"
  vpc_cidr           = "10.111.0.0/16" # EN: see live/address-plan / FR : voir live/address-plan
  min_size           = 2
  max_size           = 4
  nat_gateway_per_az = true
  availability_zones = ["ca-central-1a", "ca-central-1b"] # EN: pinned in prod / FR : épinglées en prod
  app_version        = "1.0.0"
}

output "url" {
  value = module.web.url
}

output "alb_dns_name" {
  value = module.web.alb_dns_name
}

output "alb_zone_id" {
  value = module.web.alb_zone_id
}

output "asg_name" {
  value = module.web.asg_name
}
