# =============================================================================
# Azure web platform: VNet → Standard Load Balancer (zone-redundant) → VM Scale Set across zones.
# Plateforme web Azure : VNet → Load Balancer Standard (redondant entre zones) → VM Scale Set sur plusieurs zones.
# =============================================================================

resource "azurerm_resource_group" "this" {
  count = var.create_resource_group ? 1 : 0

  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

data "azurerm_resource_group" "existing" {
  count = var.create_resource_group ? 0 : 1

  name = var.resource_group_name
}

locals {
  rg_name  = var.create_resource_group ? azurerm_resource_group.this[0].name : data.azurerm_resource_group.existing[0].name
  location = var.create_resource_group ? azurerm_resource_group.this[0].location : data.azurerm_resource_group.existing[0].location
  cloud_init = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    environment = var.environment
  })
  # EN: Wait for cloud-init (nginx installed), then render the page for THIS version.
  # FR : Attendre cloud-init (nginx installé), puis rendre la page pour CETTE version.
  render_command = "cloud-init status --wait >/dev/null; /opt/capstone/render.sh '${var.app_version}'"
}

resource "random_string" "dns" {
  length  = 6
  upper   = false
  special = false
}

# ---------------------------------------------------------------- network
resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name}"
  location            = local.location
  resource_group_name = local.rg_name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 4, 1)]
}

resource "azurerm_network_security_group" "app" {
  name                = "nsg-${var.name}-app"
  location            = local.location
  resource_group_name = local.rg_name
  tags                = var.tags

  security_rule {
    name                   = "allow-http"
    priority               = 100
    direction              = "Inbound"
    access                 = "Allow"
    protocol               = "Tcp"
    source_port_range      = "*"
    destination_port_range = "80"
    #trivy:ignore:AZU-0047 Public website by design; restrict var.allowed_cidrs for internal apps.
    source_address_prefixes    = var.allowed_cidrs
    destination_address_prefix = "*"
  }

  # EN: Health probes come from the AzureLoadBalancer service tag. / FR : Les sondes viennent de l'étiquette de service AzureLoadBalancer.
  security_rule {
    name                       = "allow-lb-probe"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-everything-else"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

# ---------------------------------------------------------------- load balancer
resource "azurerm_public_ip" "lb" {
  name                = "pip-${var.name}"
  location            = local.location
  resource_group_name = local.rg_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.zones
  domain_name_label   = "tfcap-${var.environment}-${random_string.dns.result}"
  tags                = var.tags
}

resource "azurerm_lb" "this" {
  name                = "lb-${var.name}"
  location            = local.location
  resource_group_name = local.rg_name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "app" {
  name            = "app"
  loadbalancer_id = azurerm_lb.this.id
}

resource "azurerm_lb_probe" "http" {
  name                = "healthz"
  loadbalancer_id     = azurerm_lb.this.id
  protocol            = "Http"
  port                = 80
  request_path        = "/healthz"
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "http" {
  name                           = "http"
  loadbalancer_id                = azurerm_lb.this.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "public"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.app.id]
  probe_id                       = azurerm_lb_probe.http.id
  disable_outbound_snat          = true # EN: outbound goes through the explicit rule below / FR : la sortie passe par la règle explicite ci-dessous
}

# EN: Explicit outbound for package installs: no implicit "default outbound access".
# FR : Sortie explicite pour installer les paquets : pas d'« accès sortant par défaut » implicite.
resource "azurerm_lb_outbound_rule" "egress" {
  name                    = "egress"
  loadbalancer_id         = azurerm_lb.this.id
  protocol                = "All"
  backend_address_pool_id = azurerm_lb_backend_address_pool.app.id

  frontend_ip_configuration {
    name = "public"
  }
}

# ---------------------------------------------------------------- compute
resource "azurerm_linux_virtual_machine_scale_set" "app" {
  #checkov:skip=CKV_AZURE_97:Encryption at host requires a subscription feature registration; managed disks are encrypted at rest by default.
  #checkov:skip=CKV_AZURE_50:The only extension is our own page renderer (Custom Script), reviewed with the code.
  name                            = "vmss-${var.name}"
  location                        = local.location
  resource_group_name             = local.rg_name
  sku                             = var.vm_size
  instances                       = var.min_instances
  zones                           = var.zones
  zone_balance                    = length(var.zones) > 1
  admin_username                  = "azureuser"
  disable_password_authentication = true
  custom_data                     = base64encode(local.cloud_init)
  overprovision                   = false
  tags                            = var.tags

  # EN: Rolling upgrades guided by the load balancer probe: a new app_version rolls out with no downtime.
  # FR : Mises à niveau progressives guidées par la sonde : une nouvelle app_version se déploie sans interruption.
  upgrade_mode    = "Rolling"
  health_probe_id = azurerm_lb_probe.http.id

  rolling_upgrade_policy {
    max_batch_instance_percent              = 50
    max_unhealthy_instance_percent          = 50
    max_unhealthy_upgraded_instance_percent = 50
    pause_time_between_batches              = "PT30S"
  }

  automatic_instance_repair {
    enabled      = true
    grace_period = "PT10M"
  }

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }

  # EN: Re-runs on every app_version change (force_update_tag), batch by batch, gated by the probe.
  # FR : Relancée à chaque changement d'app_version (force_update_tag), lot par lot, contrôlée par la sonde.
  extension {
    name                       = "render-page"
    publisher                  = "Microsoft.Azure.Extensions"
    type                       = "CustomScript"
    type_handler_version       = "2.1"
    auto_upgrade_minor_version = true
    force_update_tag           = var.app_version
    settings                   = jsonencode({ commandToExecute = local.render_command })
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  network_interface {
    name    = "nic"
    primary = true

    ip_configuration {
      name                                   = "primary"
      primary                                = true
      subnet_id                              = azurerm_subnet.app.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.app.id]
    }
  }

  lifecycle {
    precondition {
      condition     = var.environment != "prod" || (var.min_instances >= 2 && length(var.zones) >= 2)
      error_message = "EN: prod needs min_instances ≥ 2 across ≥ 2 zones. / FR : la prod exige min_instances ≥ 2 sur ≥ 2 zones."
    }

    # EN: The autoscale setting owns the instance count. / FR : Le paramètre de mise à l'échelle possède le nombre d'instances.
    ignore_changes = [instances]
  }

  depends_on = [azurerm_lb_rule.http, azurerm_subnet_network_security_group_association.app]
}

resource "azurerm_monitor_autoscale_setting" "cpu" {
  name                = "autoscale-${var.name}"
  location            = local.location
  resource_group_name = local.rg_name
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.app.id
  tags                = var.tags

  profile {
    name = "cpu"

    capacity {
      default = var.min_instances
      minimum = var.min_instances
      maximum = var.max_instances
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT10M"
      }
    }
  }
}
