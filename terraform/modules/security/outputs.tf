output "key_vault_id" {
  value = azurerm_key_vault.platform.id
}

output "key_vault_uri" {
  value = azurerm_key_vault.platform.vault_uri
}

output "private_endpoint_id" {
  value = azurerm_private_endpoint.key_vault.id
}
