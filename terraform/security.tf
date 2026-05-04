# ================================================================
# PFA DevSecOps Project - RBAC & Service Principal
# Least privilege access for automated systems
# ================================================================

# ──────────────────────────────────────────────────────────────
# SERVICE PRINCIPAL FOR GITHUB ACTIONS
# Robot account used by CI/CD pipeline
# Has ONLY contributor access to rami-pfa-rg
# Cannot touch billing, other resource groups, or subscriptions
# ──────────────────────────────────────────────────────────────

resource "azurerm_user_assigned_identity" "github_actions" {
  name                = "id-github-actions-pfa"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = local.common_tags
}

# ──────────────────────────────────────────────────────────────
# ROLE ASSIGNMENT: GITHUB ACTIONS → CONTRIBUTOR
# Contributor = Can create/update/delete resources
# Scope = Only rami-pfa-rg (not entire subscription)
# ──────────────────────────────────────────────────────────────

resource "azurerm_role_assignment" "github_actions_contributor" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github_actions.principal_id
}

# ──────────────────────────────────────────────────────────────
# KEY VAULT ACCESS POLICY: GITHUB ACTIONS
# GitHub Actions can only READ secrets (not write/delete)
# Follows least privilege principle
# ──────────────────────────────────────────────────────────────

resource "azurerm_key_vault_access_policy" "github_actions_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = "7af38bd4-da09-4cad-b870-0617a2df54d4"
  object_id    = azurerm_user_assigned_identity.github_actions.principal_id

  secret_permissions = [
    "Get",  # Can only READ secrets
    "List", # Can list secret names
    # Cannot Set, Delete, or Purge secrets
  ]
}

# ──────────────────────────────────────────────────────────────
# ROLE ASSIGNMENT: MONITORING READER
# Read-only access for monitoring/reporting purposes
# ──────────────────────────────────────────────────────────────

resource "azurerm_role_assignment" "monitoring_reader" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.github_actions.principal_id
}

# ──────────────────────────────────────────────────────────────
# OUTPUTS
# ──────────────────────────────────────────────────────────────

output "managed_identity_name" {
  description = "Name of the managed identity for GitHub Actions"
  value       = azurerm_user_assigned_identity.github_actions.name
}

output "managed_identity_id" {
  description = "Client ID of the managed identity"
  value       = azurerm_user_assigned_identity.github_actions.client_id
}

output "rbac_assignment" {
  description = "RBAC role assigned to GitHub Actions identity"
  value       = "Contributor on ${azurerm_resource_group.rg.name}"
}