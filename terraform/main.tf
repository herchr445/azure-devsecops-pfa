# ================================================================
# PFA DevSecOps Project - Azure Infrastructure
# Author: Rami
# Phase 2: Professional Terraform Configuration
# - Docker auto-installation via cloud-init
# - Resource tags
# - Outputs
# - Version pinning
# ================================================================

# ──────────────────────────────────────────────────────────────
# TERRAFORM & PROVIDER CONFIGURATION
# ──────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# ──────────────────────────────────────────────────────────────
# VARIABLES
# ──────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "rami"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "polandcentral"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "Production"
}

variable "vm_size" {
  description = "VM size that works in Azure Student account"
  type        = string
  default     = "Standard_B2ts_v2"
}

variable "admin_username" {
  description = "VM admin username"
  type        = string
  default     = "azureuser"
}

# ──────────────────────────────────────────────────────────────
# LOCALS (Common tags applied to all resources)
# ──────────────────────────────────────────────────────────────

locals {
  common_tags = {
    Project     = "DevSecOps-PFA"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = "Rami"
    CreatedDate = "2026-04-26"
  }
}

# ──────────────────────────────────────────────────────────────
# RESOURCE GROUP
# ──────────────────────────────────────────────────────────────

resource "azurerm_resource_group" "rg" {
  name     = "rami-pfa-rg"
  location = var.location
  tags     = local.common_tags
}

# ──────────────────────────────────────────────────────────────
# NETWORKING
# ──────────────────────────────────────────────────────────────

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.project_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags
}

# Subnet for Application VM
resource "azurerm_subnet" "subnet" {
  name                 = "${var.project_name}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.project_name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags
}

# NSG Rule: SSH (Port 22)
# Security Note: Open from anywhere (*) for development flexibility
# Authentication secured via SSH keys only (no passwords)
resource "azurerm_network_security_rule" "allow_ssh" {
  name                        = "allow-ssh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# NSG Rule: HTTP (Port 80)
resource "azurerm_network_security_rule" "allow_http" {
  name                        = "allow-http"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# NSG Rule: HTTPS (Port 443)
resource "azurerm_network_security_rule" "allow_https" {
  name                        = "allow-https"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Public IP
resource "azurerm_public_ip" "public_ip" {
  name                = "${var.project_name}-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

# Network Interface
resource "azurerm_network_interface" "nic" {
  name                = "${var.project_name}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# Associate NSG with Network Interface
resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# ──────────────────────────────────────────────────────────────
# VIRTUAL MACHINE
# ──────────────────────────────────────────────────────────────

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${var.project_name}-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username
  tags                = local.common_tags

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  # SSH Key Authentication (no passwords)
  admin_ssh_key {
    username   = var.admin_username
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCuEq1A11Ah0fJSeIL8CSwfM01ucbA6mKw3RUgiNxf0giI0EQfpugFmPyCcFtKhW77+dRN47AWP6seh5b3fAhjXBMaIhfi3i6XqKScNKBN/w5aO1rC29BQSgUBElX8XcAYDW/+KbwhZvPCnST2IyvchGKlFjTIAauCGoTk0xwY4sIYkt5Z80jw+6Pq++hGBni0m6pR1jmIfJgwToWemE/FCrQxnSZQ2hYNhV/cx3I1PPlyr20Etdhr31hN12zAVVLU3GMe6JzSRltCNh9gOh/G68hi+lKaqlCZgQyfw53IzWYGLu0sRgHk6Ka1DsOm1Vm5KrcvSw6Iy99hUYy2D28PxRFkrgU4S/PBhQPbAgRkGUcDy2SdFXgMTA4q24yjqhurHHJlTR+DwXU93NEOXsepRY0waIat0xTF/o8J4qyYxZpP0Be5U/JlQTK3lalK4V22S/EgmQX8f7UtSKDduby2sT9P9X/wn1X1/IAOq7153SAHpAsrKHQvh3oHhtwz5CrCdNDXAmSMxwBTeLyPNN85r+U5HbF18w4oyqVaNBLtSmWpTEbc2BiRuz8z2Fd8flNgidjSM/WR7sLzAH+RQxfRiUdLaFAJIrfviMVOsCQZkRXxSBpv88DwgedIeXi9NjGdaXD+DU+6slFGkqX8r3XEj4PVHOo6gRHgfhd5Iva/pww== rami horch@DESKTOP-CNU4NEO"
  }

  os_disk {
    name                 = "${var.project_name}-os-disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 50
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  disable_password_authentication = true

  # ──────────────────────────────────────────────────────────────
  # CLOUD-INIT SCRIPT
  # Automatically installs and configures software on first boot
  # ──────────────────────────────────────────────────────────────
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    
    # Update system
    echo "=== Updating system packages ==="
    apt-get update -y
    apt-get upgrade -y
    
    # Install Docker
    echo "=== Installing Docker ==="
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    
    # Add user to docker group (no sudo needed for docker commands)
    usermod -aG docker ${var.admin_username}
    
    # Install Docker Compose plugin
    echo "=== Installing Docker Compose ==="
    apt-get install -y docker-compose-plugin
    
    # Install Azure CLI
    echo "=== Installing Azure CLI ==="
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash
    
    # Install useful tools
    echo "=== Installing utilities ==="
    apt-get install -y \
      curl \
      wget \
      git \
      htop \
      vim \
      net-tools \
      unzip
    
    # Enable and start Docker
    systemctl enable docker
    systemctl start docker
    
    # Install Nginx
    echo "=== Installing Nginx ==="
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx
    
    # Create app directory
    mkdir -p /home/${var.admin_username}/app
    chown ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/app
    
    # Deployment marker
    echo "Cloud-init completed at $(date)" > /home/${var.admin_username}/cloud-init-completed.txt
    
    echo "=== Cloud-init setup complete ==="
  EOF
  )
}

# ──────────────────────────────────────────────────────────────
# OUTPUTS
# These values are displayed after terraform apply
# ──────────────────────────────────────────────────────────────

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.rg.name
}

output "vm_public_ip" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.public_ip.ip_address
}

output "vm_private_ip" {
  description = "Private IP address of the VM"
  value       = azurerm_network_interface.nic.private_ip_address
}

output "vm_name" {
  description = "Name of the virtual machine"
  value       = azurerm_linux_virtual_machine.vm.name
}

output "ssh_command" {
  description = "Command to SSH into the VM"
  value       = "ssh -i ~/.ssh/pfa_azure_key ${var.admin_username}@${azurerm_public_ip.public_ip.ip_address}"
}

output "vm_id" {
  description = "Azure resource ID of the VM"
  value       = azurerm_linux_virtual_machine.vm.id
}"# Updated" 
