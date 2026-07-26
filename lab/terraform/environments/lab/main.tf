// ─── Lab root module ─────────────────────────────────────────────────────────
// Dependency order is expressed through module outputs, not depends_on:
//   platform (Log Analytics) -> registry (ACR) -> cluster (AKS + AcrPull)

locals {
  location_abbrev = var.location_abbrev

  // The five tags the governance layer will eventually demand
  // (governance/policies/custom/require-tags.json). Applying them from day one
  // means that when you assign that policy in Phase 3, nothing breaks.
  common_tags = {
    Environment = "lab"
    CostCenter  = "CC-PERSONAL"
    Owner       = var.owner_email
    Application = "automation-lab"
    ManagedBy   = "terraform"
  }
}

module "platform" {
  source = "../../modules/platform"

  location        = var.location
  location_abbrev = local.location_abbrev
  retention_days  = var.retention_days
  daily_quota_gb  = var.daily_quota_gb
  common_tags     = local.common_tags
}

module "registry" {
  source = "../../modules/registry"

  location                   = var.location
  location_abbrev            = local.location_abbrev
  log_analytics_workspace_id = module.platform.workspace_id
  common_tags                = local.common_tags
}

module "cluster" {
  source = "../../modules/cluster"

  location                   = var.location
  location_abbrev            = local.location_abbrev
  acr_id                     = module.registry.acr_id
  log_analytics_workspace_id = module.platform.workspace_id

  node_count   = var.node_count
  node_vm_size = var.node_vm_size

  common_tags = local.common_tags
}
