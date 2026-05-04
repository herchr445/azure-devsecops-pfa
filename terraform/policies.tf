# ================================================================
# PFA DevSecOps Project - Azure Policies
# Governance rules enforced automatically
# ================================================================

# ──────────────────────────────────────────────────────────────
# POLICY 1: REQUIRE PROJECT TAG
# Denies creation of any resource without "Project" tag
# ──────────────────────────────────────────────────────────────

resource "azurerm_policy_definition" "require_project_tag" {
  name         = "require-project-tag-pfa"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Require Project tag on all resources"
  description  = "Denies creation of resources without the Project tag"

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "tags['Project']"
          exists = "false"
        }
      ]
    }
    then = {
      effect = "deny"
    }
  })
}

# Assign Policy 1 to your resource group
resource "azurerm_resource_group_policy_assignment" "require_project_tag" {
  name                 = "require-project-tag-assignment"
  resource_group_id    = azurerm_resource_group.rg.id
  policy_definition_id = azurerm_policy_definition.require_project_tag.id
  display_name         = "Require Project tag - PFA"
  description          = "Enforces Project tag on all resources in rami-pfa-rg"
}

# ──────────────────────────────────────────────────────────────
# POLICY 2: ALLOWED VM SIZES
# Only allows budget-friendly VM sizes
# Prevents accidentally creating expensive VMs
# ──────────────────────────────────────────────────────────────

resource "azurerm_policy_definition" "allowed_vm_sizes" {
  name         = "allowed-vm-sizes-pfa"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Allowed VM sizes only"
  description  = "Only allows budget-friendly VM sizes for Azure Student account"

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Compute/virtualMachines"
        },
        {
          not = {
            field = "Microsoft.Compute/virtualMachines/sku.name"
            in = [
              "Standard_B1s",
              "Standard_B1ms",
              "Standard_B2s",
              "Standard_B2ts_v2",
              "Standard_B2ms",
              "Standard_B4ms"
            ]
          }
        }
      ]
    }
    then = {
      effect = "deny"
    }
  })
}

# Assign Policy 2
resource "azurerm_resource_group_policy_assignment" "allowed_vm_sizes" {
  name                 = "allowed-vm-sizes-assignment"
  resource_group_id    = azurerm_resource_group.rg.id
  policy_definition_id = azurerm_policy_definition.allowed_vm_sizes.id
  display_name         = "Allowed VM sizes - PFA"
  description          = "Only budget-friendly VMs allowed in rami-pfa-rg"
}

# ──────────────────────────────────────────────────────────────
# POLICY 3: STORAGE HTTPS ONLY
# All storage accounts must use HTTPS only
# Prevents insecure HTTP connections
# ──────────────────────────────────────────────────────────────

resource "azurerm_policy_definition" "storage_https_only" {
  name         = "storage-https-only-pfa"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Storage accounts must use HTTPS only"
  description  = "Denies storage accounts without HTTPS-only enabled"

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Storage/storageAccounts"
        },
        {
          field  = "Microsoft.Storage/storageAccounts/supportsHttpsTrafficOnly"
          equals = "false"
        }
      ]
    }
    then = {
      effect = "deny"
    }
  })
}

# Assign Policy 3
resource "azurerm_resource_group_policy_assignment" "storage_https_only" {
  name                 = "storage-https-only-assignment"
  resource_group_id    = azurerm_resource_group.rg.id
  policy_definition_id = azurerm_policy_definition.storage_https_only.id
  display_name         = "Storage HTTPS only - PFA"
  description          = "All storage accounts must use HTTPS in rami-pfa-rg"
}

# ──────────────────────────────────────────────────────────────
# POLICY 4: REQUIRE ENVIRONMENT TAG
# All resources must have Environment tag
# Ensures proper environment classification
# ──────────────────────────────────────────────────────────────

resource "azurerm_policy_definition" "require_environment_tag" {
  name         = "require-environment-tag-pfa"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Require Environment tag on all resources"
  description  = "Denies creation of resources without the Environment tag"

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "tags['Environment']"
          exists = "false"
        }
      ]
    }
    then = {
      effect = "deny"
    }
  })
}

# Assign Policy 4
resource "azurerm_resource_group_policy_assignment" "require_environment_tag" {
  name                 = "require-environment-tag-assignment"
  resource_group_id    = azurerm_resource_group.rg.id
  policy_definition_id = azurerm_policy_definition.require_environment_tag.id
  display_name         = "Require Environment tag - PFA"
  description          = "Enforces Environment tag on all resources in rami-pfa-rg"
}

# ──────────────────────────────────────────────────────────────
# OUTPUTS
# ──────────────────────────────────────────────────────────────

output "policy_require_project_tag" {
  description = "Policy: Require Project tag"
  value       = azurerm_policy_definition.require_project_tag.display_name
}

output "policy_allowed_vm_sizes" {
  description = "Policy: Allowed VM sizes"
  value       = azurerm_policy_definition.allowed_vm_sizes.display_name
}

output "policy_storage_https" {
  description = "Policy: Storage HTTPS only"
  value       = azurerm_policy_definition.storage_https_only.display_name
}

output "policy_require_environment_tag" {
  description = "Policy: Require Environment tag"
  value       = azurerm_policy_definition.require_environment_tag.display_name
}