# ================================================================
# PFA DevSecOps Project - PostgreSQL Database
# Managed database service with private network access only
# ================================================================

# ──────────────────────────────────────────────────────────────
# DATABASE SUBNET
# Separate subnet for database (isolated from app subnet)
# App subnet:  10.0.1.0/24 (VM lives here)
# Data subnet: 10.0.2.0/24 (Database lives here)
# ──────────────────────────────────────────────────────────────

resource "azurerm_subnet" "data" {
  name                 = "${var.project_name}-subnet-data"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]

  # Special delegation required for PostgreSQL Flexible Server
  # Tells Azure: "This subnet is reserved for PostgreSQL"
  delegation {
    name = "postgresql-delegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

# ──────────────────────────────────────────────────────────────
# PRIVATE DNS ZONE
# Allows VM to find the database using a name instead of IP
# Like a phonebook: "psql-rami-pfa" → 10.0.2.5
# ──────────────────────────────────────────────────────────────

resource "azurerm_private_dns_zone" "postgresql" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags
}

# Link DNS zone to VNet
# Without this: VM can't resolve the database hostname
resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  name                  = "${var.project_name}-postgresql-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.postgresql.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  tags                  = local.common_tags
}

# ──────────────────────────────────────────────────────────────
# POSTGRESQL FLEXIBLE SERVER
# Managed PostgreSQL database - Azure handles everything
# ──────────────────────────────────────────────────────────────

resource "azurerm_postgresql_flexible_server" "main" {
  name                = "psql-${var.project_name}-pfa"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  # PostgreSQL version 15 (latest stable)
  version = "15"
  zone                = "1"

  # Connect to private subnet (no public internet access)
  delegated_subnet_id = azurerm_subnet.data.id
  private_dns_zone_id = azurerm_private_dns_zone.postgresql.id

  # Admin credentials
  administrator_login    = "psqladmin"
  administrator_password = random_password.db_password.result

  # Storage: 32GB (minimum, expandable)
  storage_mb = 32768

  # B1ms: 1 vCPU, 2GB RAM (~$15/month)
  # Budget-friendly, sufficient for demo
  sku_name = "B_Standard_B1ms"

  # Keep backups for 7 days
  backup_retention_days = 7
   public_network_access_enabled = false

  tags = local.common_tags

  # Must wait for DNS zone link before creating
  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.postgresql
  ]
}

# ──────────────────────────────────────────────────────────────
# DATABASE
# Creates the actual database inside the server
# ──────────────────────────────────────────────────────────────

resource "azurerm_postgresql_flexible_server_database" "app_db" {
  name      = "pfa_app_db"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# ──────────────────────────────────────────────────────────────
# OUTPUTS
# ──────────────────────────────────────────────────────────────

output "postgresql_server_name" {
  description = "PostgreSQL server name"
  value       = azurerm_postgresql_flexible_server.main.name
}

output "postgresql_host" {
  description = "PostgreSQL server hostname"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "postgresql_database" {
  description = "Database name"
  value       = azurerm_postgresql_flexible_server_database.app_db.name
}

output "postgresql_admin" {
  description = "PostgreSQL admin username"
  value       = azurerm_postgresql_flexible_server.main.administrator_login
}