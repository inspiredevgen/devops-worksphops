# =============================================================================
# Lab 12.A-AZ — Multi-cloud active/passive with Azure Traffic Manager (no domain needed)
# Lab 12.A-AZ — Multi-cloud actif/passif avec Azure Traffic Manager (sans nom de domaine)
#
#   client ──DNS──► tf-capstone-xxxx.trafficmanager.net ──► healthy endpoint with the LOWEST priority
#        AWS ALB (priority 1 if primary)          Azure LB (priority 1 if primary)
#   Traffic Manager probes /healthz on both; when the primary fails, DNS answers point to the other.
#   Traffic Manager sonde /healthz sur les deux ; si le principal échoue, le DNS pointe vers l'autre.
# =============================================================================

locals {
  priority = {
    aws   = var.primary == "aws" ? 1 : 2
    azure = var.primary == "azure" ? 1 : 2
  }
  tags = {
    Project   = "terraform-capstone"
    Course    = "terraform-cloud-engineer"
    Module    = "12-capstone"
    ManagedBy = "terraform"
    Owner     = "platform-team"
  }
}

resource "random_string" "dns" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "global" {
  name     = "rg-tf-capstone-global"
  location = var.location
  tags     = local.tags
}

resource "azurerm_traffic_manager_profile" "this" {
  name                   = "tm-tf-capstone-${random_string.dns.result}"
  resource_group_name    = azurerm_resource_group.global.name
  traffic_routing_method = "Priority"
  tags                   = local.tags

  dns_config {
    relative_name = "tf-capstone-${random_string.dns.result}"
    ttl           = 30 # EN: clients re-ask every 30 s, so failover reaches them quickly / FR : les clients redemandent toutes les 30 s
  }

  monitor_config {
    protocol                     = "HTTP"
    port                         = 80
    path                         = "/healthz"
    interval_in_seconds          = var.fast_probing ? 10 : 30
    timeout_in_seconds           = var.fast_probing ? 5 : 10
    tolerated_number_of_failures = 2
    expected_status_code_ranges  = ["200-200"]
  }
}

# EN: Both clouds are "external" endpoints: Traffic Manager only needs a DNS name to probe and return.
# FR : Les deux clouds sont des points de terminaison « externes » : il suffit d'un nom DNS à sonder et à renvoyer.
resource "azurerm_traffic_manager_external_endpoint" "aws" {
  name       = "aws"
  profile_id = azurerm_traffic_manager_profile.this.id
  target     = var.aws_target
  priority   = local.priority.aws
}

resource "azurerm_traffic_manager_external_endpoint" "azure" {
  name       = "azure"
  profile_id = azurerm_traffic_manager_profile.this.id
  target     = var.azure_target
  priority   = local.priority.azure
}
