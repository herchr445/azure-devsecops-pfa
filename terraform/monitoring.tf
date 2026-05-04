# ================================================================
# PFA DevSecOps Project - Monitoring Infrastructure
# Dedicated VM for Prometheus + Grafana
# Separate from app VM for independence
# ================================================================

# ──────────────────────────────────────────────────────────────
# MONITORING SUBNET
# Separate subnet for monitoring VM
# App subnet:     10.0.1.0/24 (rami-vm)
# Data subnet:    10.0.2.0/24 (PostgreSQL)
# Monitor subnet: 10.0.3.0/24 (monitor-vm)
# ──────────────────────────────────────────────────────────────

resource "azurerm_subnet" "monitor" {
  name                 = "${var.project_name}-subnet-monitor"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

# ──────────────────────────────────────────────────────────────
# PUBLIC IP FOR MONITORING VM
# Static IP so Grafana URL never changes
# ──────────────────────────────────────────────────────────────

resource "azurerm_public_ip" "monitor_ip" {
  name                = "${var.project_name}-monitor-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

# ──────────────────────────────────────────────────────────────
# NSG FOR MONITORING VM
# Opens ports needed for Grafana and Prometheus
# ──────────────────────────────────────────────────────────────

resource "azurerm_network_security_group" "monitor_nsg" {
  name                = "${var.project_name}-monitor-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags
}

# SSH access to monitoring VM
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

# Grafana UI (port 3000)
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

# Prometheus UI (port 9090)
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

# ──────────────────────────────────────────────────────────────
# NETWORK INTERFACE FOR MONITORING VM
# ──────────────────────────────────────────────────────────────

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

# Associate NSG with monitoring NIC
resource "azurerm_network_interface_security_group_association" "monitor_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.monitor_nic.id
  network_security_group_id = azurerm_network_security_group.monitor_nsg.id
}

# ──────────────────────────────────────────────────────────────
# MONITORING VM
# Standard_B1s: 1 vCPU, 1GB RAM
# Sufficient for Prometheus + Grafana (lightweight tools)
# Cloud-init installs Docker + Prometheus + Grafana automatically
# ──────────────────────────────────────────────────────────────

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

  # Cloud-init: Auto-installs Docker, Prometheus, Grafana
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    echo "=== Installing Docker ==="
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker ${var.admin_username}
    systemctl enable docker
    systemctl start docker

    echo "=== Installing Docker Compose ==="
    apt-get install -y docker-compose-plugin

    echo "=== Creating monitoring directory ==="
    mkdir -p /home/${var.admin_username}/monitoring
    chown ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/monitoring

    echo "=== Creating Prometheus config ==="
    cat > /home/${var.admin_username}/monitoring/prometheus.yml << 'PROMEOF'
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']

      - job_name: 'app-vm-node-exporter'
        static_configs:
          - targets: ['10.0.1.4:9100']
        relabel_configs:
          - source_labels: [__address__]
            target_label: instance
            replacement: 'rami-vm'
    PROMEOF

    echo "=== Creating Docker Compose file ==="
    cat > /home/${var.admin_username}/monitoring/docker-compose.yml << 'COMPEOF'
    version: '3.8'
    services:
      prometheus:
        image: prom/prometheus:latest
        container_name: prometheus
        ports:
          - "9090:9090"
        volumes:
          - ./prometheus.yml:/etc/prometheus/prometheus.yml
          - prometheus_data:/prometheus
        command:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus'
          - '--storage.tsdb.retention.time=7d'
        restart: always

      grafana:
        image: grafana/grafana:latest
        container_name: grafana
        ports:
          - "3000:3000"
        environment:
          - GF_SECURITY_ADMIN_USER=admin
          - GF_SECURITY_ADMIN_PASSWORD=PfaAdmin2026!
          - GF_USERS_ALLOW_SIGN_UP=false
        volumes:
          - grafana_data:/var/lib/grafana
        restart: always
        depends_on:
          - prometheus

    volumes:
      prometheus_data:
      grafana_data:
    COMPEOF

    echo "=== Starting monitoring stack ==="
    cd /home/${var.admin_username}/monitoring
    docker compose up -d

    echo "=== Monitoring setup complete ==="
    echo "Cloud-init completed at $(date)" > /home/${var.admin_username}/cloud-init-completed.txt
  EOF
  )
}

# ──────────────────────────────────────────────────────────────
# OUTPUTS
# ──────────────────────────────────────────────────────────────

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