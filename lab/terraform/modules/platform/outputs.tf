output "resource_group_name" {
  description = "Platform resource group name"
  value       = azurerm_resource_group.platform.name
}

output "workspace_id" {
  description = "Log Analytics workspace resource ID — wire into diagnostic settings"
  value       = azurerm_log_analytics_workspace.lab.id
}

output "workspace_name" {
  description = "Log Analytics workspace name"
  value       = azurerm_log_analytics_workspace.lab.name
}
