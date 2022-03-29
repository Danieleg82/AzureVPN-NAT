terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}


resource "azurerm_subnet" "Subnet2" {
  name                 = "Subnet2"
  resource_group_name  = var.resource_group_name
  virtual_network_name = "OnpremVNET"
  address_prefixes     = ["192.168.25.0/24"]
}

resource "azurerm_network_security_group" "OnpremSubnet2NSG" {
  name                = "OnpremSubnet2NSG"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowFromAzure"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "100.0.0.0/16"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "OnpremSubnet2NSGLink" {
  subnet_id                 = azurerm_subnet.Subnet2.id
  network_security_group_id = azurerm_network_security_group.OnpremSubnet2NSG.id
}

resource "azurerm_public_ip" "OnpremVM2PublicIP" {
  name                = "OnpremVM2PublicIP"
  resource_group_name = var.resource_group_name
  location            = var.resource_group_location
  allocation_method   = "Static"

}

resource "azurerm_network_interface" "OnpremVM2Nic" {
  name                = "OnpremVM2Nic"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.Subnet2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.OnpremVM2PublicIP.id
  }
}

resource "azurerm_linux_virtual_machine" "OnpremVM2" {
  name                = "OnpremVM2"
  resource_group_name = var.resource_group_name
  location            = var.resource_group_location
  size                = "Standard_B2s"
  admin_username      = "adminuser"
  admin_password      = "Danny_lab_82"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.OnpremVM2Nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}