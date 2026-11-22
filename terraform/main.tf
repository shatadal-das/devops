terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=5.14.0"
    }
  }
}

provider "azurerm" {
  features {}
}

// rg
resource "azurerm_resource_group" "rg" {
  name     = "my-rg"
  location = var.region
}

// vnet
resource "azurerm_virtual_network" "vnet" {
  name                = "my-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.region
  address_space       = ["10.0.0.0/16"]
}

// subnet
resource "azurerm_subnet" "snet" {
  name                 = "my-snet"
  resource_group_name  = azurerm_resource_group.rg.name
  address_prefixes     = ["10.0.0.0/24"]
  virtual_network_name = azurerm_virtual_network.vnet.name
}

// pip
resource "azurerm_public_ip" "pip" {
  count               = 3
  name                = "my-pip-${count.index}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.region
  allocation_method   = "Static"
}

// nic
resource "azurerm_network_interface" "nic" {
  count               = 3
  name                = "my-nic-${count.index}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.region

  ip_configuration {
    name                          = "ip-config"
    public_ip_address_id          = azurerm_public_ip.pip[count.index].id
    subnet_id                     = azurerm_subnet.snet.id
    private_ip_address_allocation = "Dynamic"
  }
}

// sg
resource "azurerm_network_security_group" "sg" {
  name                = "my-sg"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.region

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

// ni_sg_assoc
resource "azurerm_network_interface_security_group_association" "ni_sg_assoc" {
  count                     = 3
  network_interface_id      = azurerm_network_interface.nic[count.index].id
  network_security_group_id = azurerm_network_security_group.sg.id
}

// vm
resource "azurerm_linux_virtual_machine" "vm" {
  count                           = 3
  name                            = "my-vm-${count.index}"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = var.region
  admin_username                  = var.username
  admin_password                  = var.password
  network_interface_ids           = [azurerm_network_interface.nic[count.index].id]
  disable_password_authentication = false
  size                            = var.vmsize


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

  # custom_data = base64encode(<<-EOF
  #   #!/bin/bash
  #   apt-get update -y
  #   apt-get install -y nginx
  #   systemctl enable --now nginx
  #   echo "<h1>Hello World ${count.index}</h1>" > /var/www/html/index.html
  #   EOF
  # )
}
