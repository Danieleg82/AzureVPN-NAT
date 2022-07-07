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


data "azurerm_resource_group" "RG" {
  name     = var.resource_group_name
  
}

data "azurerm_subnet" "Subnet1" {
  name                 = "Subnet1"
  virtual_network_name = "AzureVNET"
  resource_group_name  = var.resource_group_name
}


resource "azurerm_network_interface" "AzureVM2Nic" {
  name                = "AzureVM2NIC"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.Subnet1.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "AzureVM" {
  name                = "AzureVM2"
  resource_group_name = var.resource_group_name
  location            = var.resource_group_location 
  size                = "Standard_B2s"
  admin_username      = "AdminUser"
  admin_password      = "MyVPNGWNAT_Lab!"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.AzureVM2Nic.id,
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

