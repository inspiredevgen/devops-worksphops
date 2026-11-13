# -----------------------------------------------------------------------------
# Lab 7.A-AZ (part 1) — Multi-part cloud-init with the cloudinit provider
# Lab 7.A-AZ (partie 1) — cloud-init multi-parties avec le provider cloudinit
#
# EN: Cost: Standard_B1s + Standard public IP ≈ 2 cents/hour. DESTROY after.
# FR: Coût : Standard_B1s + IP publique Standard ≈ 2 cents/heure. DÉTRUISEZ ensuite.
# -----------------------------------------------------------------------------

locals {
  tags = {
    course = "terraform-cloud-engineer"
    module = "07-provisioners"
  }

  cloud_config = {
    package_update = true
    packages       = ["nginx"]

    # EN: Staged in /opt; part 2 renders it into nginx's web root.
    # FR: Déposée dans /opt ; la partie 2 la place dans la racine web de nginx.
    write_files = [
      {
        path        = "/opt/tf-lab/index.html"
        permissions = "0644"
        content     = <<-HTML
          <!doctype html>
          <html><head><meta charset="utf-8"><title>tf-lab-m07</title></head>
          <body style="font-family: sans-serif; margin: 3rem;">
            <h1>tf-lab-m07 — ${var.environment}</h1>
            <p>Region: __REGION__</p>
            <p>Bootstrapped by / Initialisé par : cloud-init multi-part</p>
          </body></html>
        HTML
      },
    ]

    runcmd = [
      "systemctl enable --now nginx",
    ]
  }
}

# EN: custom_data must be base64. (gzip is left off on Azure for simplicity.)
# FR: custom_data doit être en base64. (gzip désactivé sur Azure par simplicité.)
data "cloudinit_config" "web" {
  gzip          = false
  base64_encode = true

  part {
    filename     = "cloud-config.yaml"
    content_type = "text/cloud-config"
    content      = yamlencode(local.cloud_config)
  }

  part {
    filename     = "configure.sh"
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/scripts/configure.sh.tftpl", { environment = var.environment })
  }
}

# EN: A READABLE copy for `terraform console` / outputs.
# FR: Une copie LISIBLE pour `terraform console` / les sorties.
data "cloudinit_config" "preview" {
  gzip          = false
  base64_encode = false

  part {
    filename     = "cloud-config.yaml"
    content_type = "text/cloud-config"
    content      = yamlencode(local.cloud_config)
  }

  part {
    filename     = "configure.sh"
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/scripts/configure.sh.tftpl", { environment = var.environment })
  }
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-tf-lab-m07-ci"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "lab" {
  name                = "vnet-tf-lab-m07-ci"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  address_space       = ["10.88.0.0/16"]
}

resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.88.1.0/24"]
}

resource "azurerm_network_security_group" "web" {
  name                = "nsg-tf-lab-m07-ci"
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
  name                = "pip-tf-lab-m07-ci"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "web" {
  name                = "nic-tf-lab-m07-ci"
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
  name                  = "vm-tf-lab-m07-ci"
  resource_group_name   = azurerm_resource_group.lab.name
  location              = azurerm_resource_group.lab.location
  size                  = "Standard_B1s"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.web.id]
  custom_data           = data.cloudinit_config.web.rendered

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
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

output "cloud_init_preview" {
  description = "EN: The multi-part document, readable / FR: Le document multi-parties, lisible"
  value       = data.cloudinit_config.preview.rendered
}
