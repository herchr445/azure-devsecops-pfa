# ================================================================
# PFA DevSecOps Project - Azure Container Registry
# Private Docker image storage for the application
# ================================================================

resource "azurerm_container_registry" "acr" {
  name                = "ramidevsecopspfa"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
  tags                = local.common_tags
}

# Store ACR credentials in Key Vault
resource "azurerm_key_vault_secret" "acr_username" {
  name         = "acr-username"
  value        = azurerm_container_registry.acr.admin_username
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_key_vault_access_policy.user_policy]
  tags         = local.common_tags
}

resource "azurerm_key_vault_secret" "acr_password" {
  name         = "acr-password"
  value        = azurerm_container_registry.acr.admin_password
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_key_vault_access_policy.user_policy]
  tags         = local.common_tags
}

# ──────────────────────────────────────────────────────────────
# OUTPUTS
# ──────────────────────────────────────────────────────────────

output "acr_login_server" {
  description = "ACR login server URL"
  value       = azurerm_container_registry.acr.login_server
}

output "acr_name" {
  description = "ACR name"
  value       = azurerm_container_registry.acr.name
}