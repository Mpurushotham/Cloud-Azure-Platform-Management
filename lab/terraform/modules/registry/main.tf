// ─── Registry: Azure Container Registry (Basic) ──────────────────────────────
// admin_enabled = false is the whole point of this module.
//
// Every ACR tutorial tells you to enable the admin user and docker-login with a
// username/password. Every real platform bans it: it is a shared static
// credential with push rights that cannot be scoped, rotated per-consumer, or
// attributed to a person. We disable it so the only way in is Entra identity —
// which forces the AcrPull managed-identity path in the cluster module.

resource "random_string" "suffix" {
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_resource_group" "registry" {
  name     = "rg-lab-acr-${var.location_abbrev}-001"
  location = var.location
  tags     = var.common_tags
}

resource "azurerm_container_registry" "lab" {
  // ACR names are globally unique, alphanumeric only, 5-50 chars.
  // The enterprise tree hardcodes globally-unique names
  // (e.g. stterraformstatedev001) which is why its state backend can never
  // initialise. A random suffix is the fix.
  name                = "acrlab${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.registry.name
  location            = azurerm_resource_group.registry.location

  sku           = "Basic"
  admin_enabled = false

  // Basic SKU does not support private endpoints, georeplication, or
  // customer-managed keys. Accepted: ~$0.167/day vs ~$0.667/day for Premium.

  tags = var.common_tags
}

// ─── Diagnostics → Log Analytics ─────────────────────────────────────────────
resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "diag-acr-to-law"
  target_resource_id         = azurerm_container_registry.lab.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "ContainerRegistryRepositoryEvents" }
  enabled_log { category = "ContainerRegistryLoginEvents" }

  // No metric block — see the note in modules/cluster/main.tf.
}
