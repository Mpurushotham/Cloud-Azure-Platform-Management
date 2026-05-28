output "hub_vnet_id" {
  description = "Hub VNet resource ID"
  value       = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  description = "Hub VNet name"
  value       = azurerm_virtual_network.hub.name
}

output "firewall_private_ip" {
  description = "Azure Firewall private IP address (used as default route next-hop)"
  value       = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

output "firewall_public_ip" {
  description = "Azure Firewall public IP address"
  value       = azurerm_public_ip.firewall.ip_address
}

output "firewall_id" {
  description = "Azure Firewall resource ID"
  value       = azurerm_firewall.hub.id
}

output "resource_group_name" {
  description = "Networking resource group name"
  value       = azurerm_resource_group.networking.name
}

output "management_subnet_id" {
  description = "Management subnet resource ID"
  value       = azurerm_subnet.management.id
}
