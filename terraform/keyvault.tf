# ================================================================
# PFA DevSecOps Project - Key Vault
# Stores all secrets securely
# ================================================================

# ──────────────────────────────────────────────────────────────
# RANDOM PASSWORD GENERATOR
# Generates a secure random password for the database
# ──────────────────────────────────────────────────────────────

resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%"
  # override_special limits special chars to safe ones
  # Avoids chars that break connection strings (@, /, :)
}

# ──────────────────────────────────────────────────────────────
# KEY VAULT
# The secure safe for all secrets
# ──────────────────────────────────────────────────────────────

resource "azurerm_key_vault" "kv" {
  name                = "kv-rami-pfa-2026"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = "7af38bd4-da09-4cad-b870-0617a2df54d4"
  sku_name            = "standard"

  # Soft delete: deleted secrets recoverable for 7 days
  soft_delete_retention_days = 7

  # Purge protection: prevents permanent deletion during retention
  purge_protection_enabled = false

  tags = local.common_tags
}

# ──────────────────────────────────────────────────────────────
# ACCESS POLICY: YOUR USER ACCOUNT
# Gives YOU full access to manage secrets
# ──────────────────────────────────────────────────────────────

resource "azurerm_key_vault_access_policy" "user_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = "7af38bd4-da09-4cad-b870-0617a2df54d4"
  object_id    = "3a70028c-53b1-4dc1-9553-f2e4a35ead9b"

  secret_permissions = [
    "Get",     # Read a secret
    "Set",     # Create/update a secret
    "List",    # List all secrets
    "Delete",  # Delete a secret
    "Purge",   # Permanently delete
    "Recover", # Recover soft-deleted secret
    "Backup",  # Backup a secret
    "Restore", # Restore a secret
  ]
}

# ──────────────────────────────────────────────────────────────
# SECRET: DATABASE PASSWORD
# Stores the auto-generated database password
# ──────────────────────────────────────────────────────────────

resource "azurerm_key_vault_secret" "db_password" {
  name         = "postgresql-admin-password"
  value        = random_password.db_password.result
  key_vault_id = azurerm_key_vault.kv.id

  tags = local.common_tags

  # Must wait for access policy before creating secret
  depends_on = [azurerm_key_vault_access_policy.user_policy]
}

# ──────────────────────────────────────────────────────────────
# SECRET: APPLICATION SECRET KEY
# Used by Node.js app for session encryption
# ──────────────────────────────────────────────────────────────

resource "azurerm_key_vault_secret" "app_secret" {
  name         = "app-secret-key"
  value        = random_password.db_password.result
  key_vault_id = azurerm_key_vault.kv.id

  tags = local.common_tags

  depends_on = [azurerm_key_vault_access_policy.user_policy]
}

# ──────────────────────────────────────────────────────────────
# OUTPUTS
# ──────────────────────────────────────────────────────────────

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.kv.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.kv.vault_uri
}

output "db_password_secret_name" {
  description = "Name of the DB password secret in Key Vault"
  value       = azurerm_key_vault_secret.db_password.name
}