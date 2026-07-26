// ─── Platform: resource group + Log Analytics workspace ──────────────────────
// The observability root. Everything else sends diagnostics here.
//
// Cost note: PerGB2018 bills per GB ingested. With Container Insights OFF
// (see the cluster module) ingestion is a trickle — control-plane logs only.

resource "azurerm_resource_group" "platform" {
  name     = "rg-lab-platform-${var.location_abbrev}-001"
  location = var.location
  tags     = var.common_tags
}

resource "azurerm_log_analytics_workspace" "lab" {
  name                = "law-lab-${var.location_abbrev}-001"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name

  sku               = "PerGB2018"
  retention_in_days = var.retention_days

  // Hard cap on ingestion. The enterprise tree sets dailyQuotaGb: -1
  // (uncapped) in monitoring/log-analytics/main.bicep:19 — deliberately NOT
  // copied here. On a credit-funded lab an uncapped workspace is how you
  // wake up to a surprise.
  daily_quota_gb = var.daily_quota_gb

  tags = var.common_tags
}
