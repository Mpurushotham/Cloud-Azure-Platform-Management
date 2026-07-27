// ─── Cluster: VNet + AKS (Free tier) + AcrPull binding ───────────────────────
// Shaped by one hard constraint: the subscription's regional quota is 4 vCPU.
// AKS's default node pool is 3 x Standard_DS2_v2 = 6 vCPU and fails outright.
// One 2-vCPU node is the only shape that fits.

resource "azurerm_resource_group" "cluster" {
  name     = "rg-lab-aks-${var.location_abbrev}-001"
  location = var.location
  tags     = var.common_tags
}

// ─── Network ─────────────────────────────────────────────────────────────────
// 10.50.0.0/16 is deliberately outside the enterprise tree's ranges
// (10.0 hub / 10.10 corp / 10.20 online) so lab and reference can never be
// confused, and a future hub peering can't collide.
resource "azurerm_virtual_network" "lab" {
  name                = "vnet-lab-${var.location_abbrev}-001"
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  address_space       = [var.vnet_address_space]
  tags                = var.common_tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.cluster.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.aks_subnet_prefix]
}

// ─── AKS ─────────────────────────────────────────────────────────────────────
resource "azurerm_kubernetes_cluster" "lab" {
  name                = "aks-lab-${var.location_abbrev}-001"
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  dns_prefix          = "aks-lab-${var.location_abbrev}"

  // Free tier: control plane costs nothing and carries no uptime SLA.
  // "Standard" would add ~$0.10/hr for an SLA a lab does not need.
  sku_tier = "Free"

  // Let Azure pick a supported version rather than pinning one that ages out
  // of support and blocks apply. Pin this in a real platform.
  automatic_upgrade_channel = "patch"

  default_node_pool {
    name            = "system"
    node_count      = var.node_count
    vm_size         = var.node_vm_size
    os_disk_size_gb = var.os_disk_size_gb
    vnet_subnet_id  = azurerm_subnet.aks.id

    // No autoscaling: with 4 vCPU of quota there is nothing to scale into,
    // and a surprise scale-out is a surprise bill.
    auto_scaling_enabled = false

    upgrade_settings {
      max_surge = "10%" // 0 extra nodes at count=1; avoids a quota-blocked upgrade
    }
  }

  // System-assigned identity, not a service principal with a secret.
  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay" // pod IPs come from pod_cidr, not the subnet
    network_policy      = "calico"

    pod_cidr       = var.pod_cidr
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip

    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer" // creates one egress PIP in the MC_* RG
  }

  // NOTE: oms_agent (Container Insights) is deliberately ABSENT.
  // It is the single largest hidden cost in an AKS lab — it ingests every
  // container's stdout at per-GB rates. Enable it consciously in Phase 4,
  // measure the ingestion, then decide.

  tags = var.common_tags

  lifecycle {
    ignore_changes = [
      // AKS patches the control plane itself under the "patch" channel;
      // don't let Terraform fight it on every plan.
      kubernetes_version,
    ]
  }
}

// ─── ACR pull, via managed identity — no imagePullSecret ─────────────────────
// The kubelet identity is a *separate* identity from the cluster's control-plane
// identity. Granting AcrPull to the kubelet is what lets nodes pull images with
// no registry credential anywhere in the cluster.
//
// Expect a few minutes of propagation delay: the first pod pull immediately
// after apply can fail with 401. That is RBAC replication, not a broken config.
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = var.acr_id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.lab.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

// ─── Diagnostics → Log Analytics ─────────────────────────────────────────────
// Only two categories. kube-audit / kube-audit-admin are intentionally omitted:
// they are extremely high-volume and would dominate the ingestion cap.
resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "diag-aks-to-law"
  target_resource_id         = azurerm_kubernetes_cluster.lab.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "kube-apiserver" }
  enabled_log { category = "kube-controller-manager" }

  // No metric block at all: platform metrics are free to view in Azure Monitor
  // but chargeable to *ingest* into Log Analytics. Omitting is cheaper than
  // declaring them disabled, and avoids the deprecated `metric` argument
  // (removed in azurerm v5).
}
