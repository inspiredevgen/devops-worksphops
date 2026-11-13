# =============================================================================
# load_balancer = true: a Standard Load Balancer in front of every VM with role "web".
#   HTTP probe GET /healthz every 5 s; a VM leaves the pool after 2 failed probes.
#   Ansible drains a VM by making /healthz answer 503 (no change to the pool itself: Terraform stays the owner).
# load_balancer = true : un Standard Load Balancer devant chaque VM de rôle « web ».
#   Ansible retire une VM en faisant répondre 503 à /healthz (aucun changement du pool : Terraform en reste propriétaire).
# =============================================================================
locals {
  lb       = var.load_balancer
  web_keys = [for k, h in var.hosts : k if h.role == "web"]
}

resource "azurerm_public_ip" "lb" {
  count = local.lb ? 1 : 0

  name                = "pip-ans-lab-lb"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags

  lifecycle {
    precondition {
      condition     = local.ssh && var.my_ip != null && contains(var.open_ports, 80)
      error_message = "EN: load_balancer needs access = \"ssh\", my_ip and open_ports = [80] (Azure LB keeps the client IP). / FR : load_balancer exige access = « ssh », my_ip et open_ports = [80]."
    }
  }
}

resource "azurerm_lb" "web" {
  count = local.lb ? 1 : 0

  name                = "lb-ans-lab-web"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "Standard"
  tags                = local.tags

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.lb[0].id
  }
}

resource "azurerm_lb_backend_address_pool" "web" {
  count = local.lb ? 1 : 0

  name            = "web"
  loadbalancer_id = azurerm_lb.web[0].id
}

resource "azurerm_lb_probe" "healthz" {
  count = local.lb ? 1 : 0

  name                = "healthz"
  loadbalancer_id     = azurerm_lb.web[0].id
  protocol            = "Http"
  port                = 80
  request_path        = "/healthz"
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "http" {
  count = local.lb ? 1 : 0

  name                           = "http"
  loadbalancer_id                = azurerm_lb.web[0].id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "public"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web[0].id]
  probe_id                       = azurerm_lb_probe.healthz[0].id
  disable_outbound_snat          = true # EN: the VMs have their own public IPs / FR : les VM ont leurs propres IP publiques
}

resource "azurerm_network_interface_backend_address_pool_association" "web" {
  for_each = local.lb ? toset(local.web_keys) : toset([])

  network_interface_id    = azurerm_network_interface.host[each.key].id
  ip_configuration_name   = "primary"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web[0].id
}
