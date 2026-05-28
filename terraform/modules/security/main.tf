terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }
}

# ─── Key Vault ────────────────────────────────────────────────────────────────
resource "azurerm_key_vault" "platform" {
  name                        = var.key_vault_name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "premium"
  enable_rbac_authorization   = true
  soft_delete_retention_days  = 90
  purge_protection_enabled    = true
  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = merge(var.common_tags, {
    Application = "platform-secrets"
  })
}

data "azurerm_client_config" "current" {}

# ─── Private Endpoint for Key Vault ──────────────────────────────────────────
resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-${var.key_vault_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "pe-${var.key_vault_name}-connection"
    private_connection_resource_id = azurerm_key_vault.platform.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  tags = var.common_tags
}

# ─── Defender for Cloud Plans ─────────────────────────────────────────────────
resource "azurerm_security_center_subscription_pricing" "servers" {
  tier          = "Standard"
  resource_type = "VirtualMachines"
  subplan       = "P2"
}

resource "azurerm_security_center_subscription_pricing" "storage" {
  tier          = "Standard"
  resource_type = "StorageAccounts"
}

resource "azurerm_security_center_subscription_pricing" "sql" {
  tier          = "Standard"
  resource_type = "SqlServers"
}

resource "azurerm_security_center_subscription_pricing" "app_service" {
  tier          = "Standard"
  resource_type = "AppServices"
}

resource "azurerm_security_center_subscription_pricing" "containers" {
  tier          = "Standard"
  resource_type = "Containers"
}

resource "azurerm_security_center_subscription_pricing" "key_vault" {
  tier          = "Standard"
  resource_type = "KeyVaults"
}

# ─── Diagnostic Settings for Key Vault ───────────────────────────────────────
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "diag-${var.key_vault_name}"
  target_resource_id         = azurerm_key_vault.platform.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "AuditEvent" }
  enabled_log { category = "AzurePolicyEvaluationDetails" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
