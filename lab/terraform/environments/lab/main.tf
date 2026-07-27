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

  // AKS names its node resource group MC_<rg>_<cluster>_<region> unless
  // node_resource_group is set explicitly. Deriving the name here rather than
  // reading module.cluster.node_resource_group keeps the governance module
  // independent of the cluster, so policy can be created, kept and destroyed on
  // its own schedule. The names below must track modules/cluster/main.tf.
  aks_resource_group = "rg-lab-aks-${local.location_abbrev}-001"
  aks_cluster_name   = "aks-lab-${local.location_abbrev}-001"
  aks_node_resource_group = format("MC_%s_%s_%s",
    local.aks_resource_group, local.aks_cluster_name, var.location
  )
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

// ─── Governance (Phase 3) ────────────────────────────────────────────────────
// Assigned at SUBSCRIPTION scope, because management-group scope requires root-MG
// elevation this subscription does not have. Ships audit-only: see the module's
// precondition, which refuses to enforce a public-IP Deny without an exclusion.
module "governance" {
  source = "../../modules/governance"

  subscription_scope_id = "/subscriptions/${var.subscription_id}"

  enforce           = var.policy_enforce
  tag_effect        = var.policy_tag_effect
  location_effect   = var.policy_location_effect
  public_ip_effect  = var.policy_public_ip_effect
  tls_effect        = var.policy_tls_effect
  allowed_locations = [var.location]

  // Scopes excluded because Azure itself creates resources there that you do not
  // author and cannot tag at creation time. Both were found empirically by
  // running the baseline in audit mode — see lab/scripts/policy-compliance.sh.
  //
  // These are DERIVED NAMES, deliberately not module.cluster.node_resource_group.
  // Referencing the cluster output made governance a dependent of the cluster, so
  // `terraform destroy -target=module.cluster` took the policy assignment with it
  // — governance must outlive the workloads it governs, not die alongside them.
  // A not_scopes entry may name a scope that does not exist yet, or any more.
  excluded_scope_ids = [
    // AKS owns everything in MC_*: load balancers, NSGs, route tables, the
    // egress public IP, CSI-provisioned disks. Created untagged, outside your
    // control, so a tag or public-IP Deny here breaks the cluster.
    "/subscriptions/${var.subscription_id}/resourceGroups/${local.aks_node_resource_group}",

    // Azure auto-creates NetworkWatcherRG + networkwatcher_<region> the moment a
    // VNet appears in a region, untagged, in a resource group you never asked
    // for. You can tag the instance, but the next new region silently creates
    // another one — so tagging is not a durable fix and exclusion is.
    "/subscriptions/${var.subscription_id}/resourceGroups/NetworkWatcherRG",
  ]
}
