# -----------------------------------------------------------------------------
# Lab 7.A-AZ (part 3) — Deploy the baked image
# Lab 7.A-AZ (partie 3) — Déployer l'image préconstruite
#
# EN: SOFTWARE is in the image; CONFIGURATION is injected at boot by a tiny
#     custom_data. Cost: Standard_B1s + public IP ≈ 2 cents/hour. DESTROY after.
# FR: Le LOGICIEL est dans l'image ; la CONFIGURATION est injectée au démarrage
#     par un petit custom_data. Coût : Standard_B1s + IP publique ≈ 2 cents/heure.
#     DÉTRUISEZ ensuite.
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

variable "subscription_id" {
  description = "EN: Subscription ID (or ARM_SUBSCRIPTION_ID) / FR: ID d'abonnement (ou ARM_SUBSCRIPTION_ID)"
  type        = string
  default     = null
}

variable "location" {
  description = "EN: Azure region / FR: Région Azure"
  type        = string
  default     = "canadacentral"
}

variable "my_ip" {
  description = "EN: Your public IPv4 (no /32) / FR: Votre IPv4 publique (sans /32)"
  type        = string

  validation {
    condition     = can(cidrhost("${var.my_ip}/32", 0))
    error_message = "EN: A plain IPv4 address. / FR : Une adresse IPv4 simple."
  }
}

variable "ssh_public_key_path" {
  description = "EN: SSH public key / FR: Clé SSH publique"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "page_message" {
  description = "EN: Runtime configuration injected at boot / FR: Configuration injectée au démarrage"
  type        = string
  default     = "Booted from a golden image / Démarré depuis une image golden"
}

# EN: The newest image built by Packer (sorted by name → timestamp suffix).
# FR: L'image la plus récente construite par Packer (triée par nom → suffixe horodaté).
data "azurerm_image" "web" {
  name_regex          = "^img-tf-lab-m07-web-"
  sort_descending     = true
  resource_group_name = "rg-tf-lab-m07-images"
}

locals {
  tags = {
    course = "terraform-cloud-engineer"
    module = "07-provisioners"
  }
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-tf-lab-m07-baked"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "lab" {
  name                = "vnet-tf-lab-m07-baked"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  address_space       = ["10.89.0.0/16"]
}

resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.89.1.0/24"]
}

resource "azurerm_network_security_group" "web" {
  name                = "nsg-tf-lab-m07-baked"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location

  security_rule {
    name                       = "http-from-my-ip"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "${var.my_ip}/32"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_public_ip" "web" {
  name                = "pip-tf-lab-m07-baked"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "web" {
  name                = "nic-tf-lab-m07-baked"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web.id
  }
}

resource "azurerm_linux_virtual_machine" "web" {
  name                  = "vm-tf-lab-m07-baked"
  resource_group_name   = azurerm_resource_group.lab.name
  location              = azurerm_resource_group.lab.location
  size                  = "Standard_B1s"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.web.id]

  # EN: The golden image instead of a marketplace image.
  # FR: L'image golden au lieu d'une image de la place de marché.
  source_image_id = data.azurerm_image.web.id

  # EN: CONFIG only — nginx is already installed and enabled in the image.
  # FR: CONFIGURATION seulement — nginx est déjà installé et activé dans l'image.
  custom_data = base64encode(join("\n", ["#cloud-config", yamlencode({
    write_files = [{
      path        = "/var/www/html/index.html"
      permissions = "0644"
      content     = "<!doctype html><meta charset=\"utf-8\"><h1>tf-lab-m07 (baked)</h1><p>${var.page_message}</p><p>Image: ${data.azurerm_image.web.name}</p>"
    }]
  })]))

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  tags       = local.tags
  depends_on = [azurerm_subnet_network_security_group_association.web]
}

resource "terraform_data" "time_to_healthy" {
  triggers_replace = [azurerm_linux_virtual_machine.web.id]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = { URL = "http://${azurerm_public_ip.web.ip_address}/healthz" }
    command     = <<-EOT
      for i in $(seq 1 72); do
        if curl -sf -m 5 "$URL" >/dev/null; then echo "HEALTHY after $SECONDS s"; exit 0; fi
        sleep 5
      done
      echo "NOT healthy after $SECONDS s"; exit 1
    EOT
  }
}

output "url" {
  description = "EN: Web server URL / FR: URL du serveur web"
  value       = "http://${azurerm_public_ip.web.ip_address}"
}

output "image" {
  description = "EN: Golden image used / FR: Image golden utilisée"
  value       = data.azurerm_image.web.name
}
