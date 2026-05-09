# ================================================================
# PFA DevSecOps Project - Monitoring Infrastructure
# Dedicated VM for Prometheus + Grafana
# ================================================================

resource "azurerm_subnet" "monitor" {
  name                 = "${var.project_name}-subnet-monitor"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_public_ip" "monitor_ip" {
  name                = "${var.project_name}-monitor-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_network_security_group" "monitor_nsg" {
  name                = "${var.project_name}-monitor-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags
}

resource "azurerm_network_security_rule" "monitor_ssh" {
  name                        = "allow-ssh-monitor"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.monitor_nsg.name
}

resource "azurerm_network_security_rule" "monitor_grafana" {
  name                        = "allow-grafana"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3000"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.monitor_nsg.name
}

resource "azurerm_network_security_rule" "monitor_prometheus" {
  name                        = "allow-prometheus"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "9090"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.monitor_nsg.name
}

resource "azurerm_network_interface" "monitor_nic" {
  name                = "${var.project_name}-monitor-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.monitor.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.monitor_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "monitor_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.monitor_nic.id
  network_security_group_id = azurerm_network_security_group.monitor_nsg.id
}

resource "azurerm_linux_virtual_machine" "monitor_vm" {
  name                = "${var.project_name}-monitor-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2ts_v2"
  admin_username      = var.admin_username
  tags                = local.common_tags

  network_interface_ids = [
    azurerm_network_interface.monitor_nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCuEq1A11Ah0fJSeIL8CSwfM01ucbA6mKw3RUgiNxf0giI0EQfpugFmPyCcFtKhW77+dRN47AWP6seh5b3fAhjXBMaIhfi3i6XqKScNKBN/w5aO1rC29BQSgUBElX8XcAYDW/+KbwhZvPCnST2IyvchGKlFjTIAauCGoTk0xwY4sIYkt5Z80jw+6Pq++hGBni0m6pR1jmIfJgwToWemE/FCrQxnSZQ2hYNhV/cx3I1PPlyr20Etdhr31hN12zAVVLU3GMe6JzSRltCNh9gOh/G68hi+lKaqlCZgQyfw53IzWYGLu0sRgHk6Ka1DsOm1Vm5KrcvSw6Iy99hUYy2D28PxRFkrgU4S/PBhQPbAgRkGUcDy2SdFXgMTA4q24yjqhurHHJlTR+DwXU93NEOXsepRY0waIat0xTF/o8J4qyYxZpP0Be5U/JlQTK3lalK4V22S/EgmQX8f7UtSKDduby2sT9P9X/wn1X1/IAOq7153SAHpAsrKHQvh3oHhtwz5CrCdNDXAmSMxwBTeLyPNN85r+U5HbF18w4oyqVaNBLtSmWpTEbc2BiRuz8z2Fd8flNgidjSM/WR7sLzAH+RQxfRiUdLaFAJIrfviMVOsCQZkRXxSBpv88DwgedIeXi9NjGdaXD+DU+6slFGkqX8r3XEj4PVHOo6gRHgfhd5Iva/pww== rami horch@DESKTOP-CNU4NEO"
  }

  os_disk {
    name                 = "${var.project_name}-monitor-os-disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  disable_password_authentication = true
  # cloud-init handled during initial deployment
}

output "monitor_vm_public_ip" {
  description = "Public IP of monitoring VM"
  value       = azurerm_public_ip.monitor_ip.ip_address
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://${azurerm_public_ip.monitor_ip.ip_address}:3000"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${azurerm_public_ip.monitor_ip.ip_address}:9090"
}

output "grafana_credentials" {
  description = "Grafana login credentials"
  value       = "admin / PfaAdmin2026!"
}