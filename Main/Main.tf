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
#Azure part creation:
###################################################################################
###################################################################################
###################################################################################

resource "azurerm_resource_group" "RG" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

#Create VNET
resource "azurerm_virtual_network" "AZUREVNET" {
  name                = "AzureVNET"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.RG.name
  address_space       = ["10.0.0.0/16"]
}

#Create Subnet1
resource "azurerm_subnet" "AzureVMSubnet" {
  name                 = "Subnet1"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.AZUREVNET.name
  
  address_prefixes     = ["10.0.1.0/24"]
  }


#Create GWsubnet
resource "azurerm_subnet" "GWSubnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.AZUREVNET.name
  address_prefixes     = ["10.0.2.0/24"]
}

#Create Azure gateway VIP
resource "azurerm_public_ip" "AzureGWVIP" {
  name                = "AzureGWVIP"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  allocation_method   = "Dynamic"
}

#Create AzureVM NIC
resource "azurerm_network_interface" "AzureVMNic" {
  name                = "AzureVMNIC"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.AzureVMSubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

#Create AzureVM
resource "azurerm_linux_virtual_machine" "AzureVM" {
  name                = "AzureVM"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  size                = "Standard_B2s"
  admin_username      = "AdminUser"
  admin_password      = "MyVPNGWNAT_Lab!"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.AzureVMNic.id,
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

#Create Azure GW
resource "azurerm_virtual_network_gateway" "AzureGW" {
  name                = "AzureGW"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = true
  sku           = "VpnGw2"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.AzureGWVIP.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.GWSubnet.id
  }

}

###################################################################################
#Create Bastion for AzureVNET environment
###################################################################################

resource "azurerm_virtual_network" "BastionForAzureVNET" {
  name                = "BastionForAzureVNET"
  address_space       = ["192.168.170.0/24"]
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
}

resource "azurerm_subnet" "BastionAzSubnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.RG.name
  virtual_network_name = azurerm_virtual_network.AZUREVNET.name
  address_prefixes     = ["10.0.35.0/27"]
}

resource "azurerm_public_ip" "BastionAzVIP" {
  name                = "BastionAzVIP"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "BastionAZ" {
  name                = "BastionAZ"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.BastionAzSubnet.id
    public_ip_address_id = azurerm_public_ip.BastionAzVIP.id
  }
}

###################################################################################
#Create Bastion for Onprem environment
###################################################################################

resource "azurerm_subnet" "BastionOnprSubnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.RG.name
  virtual_network_name = azurerm_virtual_network.OnpremVNET.name
  address_prefixes     = ["10.0.35.0/27"]
}

resource "azurerm_public_ip" "BastionOnprVIP" {
  name                = "BastionOnprVIP"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "BastionOnpr" {
  name                = "BastionOnpr"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.BastionOnprSubnet.id
    public_ip_address_id = azurerm_public_ip.BastionOnprVIP.id
  }
}


###################################################################################
#Onprem  part creation:
###################################################################################
###################################################################################
###################################################################################


#Create Onprem VNET
resource "azurerm_virtual_network" "OnpremVNET" {
  name                = "OnpremVNET"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.RG.name
  address_space       = ["10.0.0.0/16"]
}

#Create first Onprem subnet
resource "azurerm_subnet" "OnpremVMSubnet" {
  name                 = "Subnet1"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.OnpremVNET.name
  address_prefixes     = ["10.0.1.0/24"]
}



###################################################################################

#Create Internal CSR subnet
resource "azurerm_subnet" "CSRInternalSubnet" {
  name                 = "CSRInternalSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.OnpremVNET.name
  address_prefixes     = ["10.0.10.0/24"]
}

#Create External CSR subnet
resource "azurerm_subnet" "CSRExternalSubnet" {
  name                 = "CSRExternalSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.OnpremVNET.name
  address_prefixes     = ["10.0.3.0/24"]
}


#Create public IP of the CSR
resource "azurerm_public_ip" "CSRVIP" {
  name                = "CSRVIP"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  allocation_method   = "Static"
}

#Create NIC for OnpremVM
resource "azurerm_network_interface" "OnpremVMNic" {
  name                = "OnpremVMNic"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.OnpremVMSubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

#Create OnpremVM
resource "azurerm_linux_virtual_machine" "OnpremVM" {
  name                = "OnpremVM"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  size                = "Standard_B2s"
  admin_username      = "AdminUser"
  admin_password      = "MyVPNGWNAT_Lab!"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.OnpremVMNic.id,
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

#Create Internal CSR NIC
resource "azurerm_network_interface" "CSRInternalNIC" {
  name                = "CSRInternalNIC"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.CSRInternalSubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

#Create External CSR NIC
resource "azurerm_network_interface" "CSRExternalNIC" {
  name                = "CSRExternalNIC"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "external"
    subnet_id                     = azurerm_subnet.CSRExternalSubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.CSRVIP.id
  }
}

#Create CSR
resource "azurerm_virtual_machine" "OnpremCSR" {
  name  = "CSR"
  location  = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  vm_size = "Standard_DS3_v2"
  delete_data_disks_on_termination = true
  delete_os_disk_on_termination    = true
  primary_network_interface_id     = azurerm_network_interface.CSRExternalNIC.id
  network_interface_ids = [azurerm_network_interface.CSRExternalNIC.id,
  azurerm_network_interface.CSRInternalNIC.id]

  plan {
    publisher = "cisco"
    product   = "cisco-csr-1000v"
    name      = "17_2_1-byol"
  }
  storage_os_disk {
    name              = "csrDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  storage_image_reference {
    publisher = "cisco"
    offer     = "cisco-csr-1000v"
    sku       = "17_2_1-byol"
    version   = "17.2.120200508"
  }
  os_profile {
    admin_username = "AdminUser"
    admin_password = "MyVPNGWNAT_Lab!"
    computer_name  = "CSR0"
  }
}

###################################################################################
###################################################################################

