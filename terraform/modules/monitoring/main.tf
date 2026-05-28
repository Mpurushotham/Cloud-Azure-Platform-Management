terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }
}

# ─── Log Analytics Workspace ─────────────────────────────────────────────────
resource "azurerm_log_analytics_workspace" "platform" {
  name                = var.workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_days

  tags = merge(var.common_tags, {
    Application = "platform-monitoring"
  })
}

# ─── Solutions ────────────────────────────────────────────────────────────────
locals {
  solutions = [
    { name = "VMInsights",          product = "OMSGallery/VMInsights" },
    { name = "ContainerInsights",   product = "OMSGallery/ContainerInsights" },
    { name = "ChangeTracking",      product = "OMSGallery/ChangeTracking" },
    { name = "Updates",             product = "OMSGallery/Updates" },
    { name = "AzureActivity",       product = "OMSGallery/AzureActivity" },
  ]
}

resource "azurerm_log_analytics_solution" "solutions" {
  for_each            = { for s in local.solutions : s.name => s }
  solution_name       = each.value.name
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.platform.id
  workspace_name        = azurerm_log_analytics_workspace.platform.name

  plan {
    publisher = "Microsoft"
    product   = each.value.product
  }
}

# ─── Action Group ─────────────────────────────────────────────────────────────
resource "azurerm_monitor_action_group" "critical" {
  name                = "ag-critical-${var.environment}"
  resource_group_name = var.resource_group_name
  short_name          = "CritAlert"

  dynamic "email_receiver" {
    for_each = var.alert_email_addresses
    content {
      name                    = "email-${md5(email_receiver.value)}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }

  tags = var.common_tags
}

# ─── Outputs ─────────────────────────────────────────────────────────────────
output "workspace_id" {
  value = azurerm_log_analytics_workspace.platform.id
}

output "workspace_name" {
  value = azurerm_log_analytics_workspace.platform.name
}

output "workspace_customer_id" {
  value = azurerm_log_analytics_workspace.platform.workspace_id
}

output "critical_action_group_id" {
  value = azurerm_monitor_action_group.critical.id
}
