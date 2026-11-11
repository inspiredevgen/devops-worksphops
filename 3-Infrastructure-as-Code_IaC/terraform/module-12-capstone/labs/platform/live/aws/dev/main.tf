# =============================================================================
# Capstone · AWS · dev
# =============================================================================

module "web" {
  source = "../../../modules/aws-web"

  name               = "tf-capstone-dev"
  environment        = "dev"
  vpc_cidr           = "10.110.0.0/16" # EN: see live/address-plan / FR : voir live/address-plan
  min_size           = 1
  max_size           = 2
  nat_gateway_per_az = false
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
