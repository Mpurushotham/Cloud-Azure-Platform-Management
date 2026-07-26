output "acr_id" {
  description = "Registry resource ID — scope for the AcrPull role assignment"
  value       = azurerm_container_registry.lab.id
}

output "acr_name" {
  description = "Registry name (use with: az acr build --registry <name>)"
  value       = azurerm_container_registry.lab.name
}

output "login_server" {
  description = "Registry login server, e.g. acrlab1234.azurecr.io"
  value       = azurerm_container_registry.lab.login_server
}
