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


###################################################################################
#Azure :
###################################################################################
###################################################################################

#NSG for Subnet1
###################################################################################

resource "azurerm_network_security_group" "AzureVMNSG" {
  name                = "AzureVMNSG"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowOnprem"
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

resource "azurerm_subnet_network_security_group_association" "AzureVMNSGlink" {
  subnet_id                 = azurerm_subnet.AzureVMSubnet.id
  network_security_group_id = azurerm_network_security_group.AzureVMNSG.id
}

###################################################################################

###################################################################################
#Onprem  part creation:
###################################################################################
###################################################################################

#Create NSGs for Onprem Subnet1

###################################################################################
resource "azurerm_network_security_group" "OnpremSubnetNSG" {
  name                = "OnpremSubnetNSG"
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

resource "azurerm_subnet_network_security_group_association" "OnpremSubnetNSGLink" {
  subnet_id                 = azurerm_subnet.OnpremVMSubnet.id
  network_security_group_id = azurerm_network_security_group.OnpremSubnetNSG.id
}


###################################################################################

#Create NSGs for CSR External subnet

###################################################################################
resource "azurerm_network_security_group" "CSRExternalNSG" {
  name                = "CSRExternalNSG"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowfromGWVIP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureCLoud.${var.resource_group_location}"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "CSRExternalNSGlink" {
  subnet_id                 = azurerm_subnet.CSRExternalSubnet.id
  network_security_group_id = azurerm_network_security_group.CSRExternalNSG.id
}

###################################################################################

#Create NSGs for CSR Internal subnet
resource "azurerm_network_security_group" "CSRInternalNSG" {
  name                = "CSRInternalNSG"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowToAzure"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes     = ["10.0.1.0/24","192.168.25.0/24"]
    destination_address_prefix = "100.0.0.0/16"
  }
}

resource "azurerm_subnet_network_security_group_association" "CSRInternalNSGlink" {
  subnet_id                 = azurerm_subnet.CSRInternalSubnet.id
  network_security_group_id = azurerm_network_security_group.CSRInternalNSG.id
}

###################################################################################
