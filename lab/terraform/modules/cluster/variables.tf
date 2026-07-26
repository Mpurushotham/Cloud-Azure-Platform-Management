variable "location" {
  description = "Azure region for the cluster"
  type        = string
}

variable "location_abbrev" {
  description = "Short region code used in resource names (e.g. eus)"
  type        = string
}

variable "acr_id" {
  description = "ACR resource ID to grant the kubelet identity AcrPull on"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Workspace to send cluster diagnostics to"
  type        = string
}

// ─── Sizing — constrained by a 4 vCPU regional quota ─────────────────────────

variable "node_count" {
  description = "Node count. Must stay 1 on a 4 vCPU quota."
  type        = number
  default     = 1

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 2
    error_message = "node_count must be 1 or 2 — a 4 vCPU quota cannot host more 2-vCPU nodes."
  }
}

variable "node_vm_size" {
  description = "Node SKU. Standard_D2as_v7 = 2 vCPU / 8 GiB (AMD)."
  type        = string
  default     = "Standard_D2as_v7"

  // Why not Standard_B2s (the obvious cheap choice)? This subscription is not
  // offered ANY burstable SKU in eastus — AKS rejects it with
  // "The VM size of Standard_B2s is not allowed in your subscription in
  // location 'eastus'". Quota existed (standardBSFamily = 4); availability did
  // not. Those are two different gates and both must pass.
  //
  // Verified available and unrestricted here, all 2 vCPU:
  //   Standard_D2as_v7  8 GiB  AMD    <- chosen: most RAM per currency unit
  //   Standard_D2s_v7   8 GiB  Intel
  //   Standard_D2ds_v7  8 GiB  Intel
  //   Standard_D2ls_v7  4 GiB  Intel  (cheapest, but tight for AKS system pods)
}

variable "os_disk_size_gb" {
  description = "Node OS disk size. 30 GiB is the Azure minimum."
  type        = number
  default     = 32

  validation {
    condition     = var.os_disk_size_gb >= 30
    error_message = "os_disk_size_gb must be at least 30."
  }
}

// ─── Addressing ──────────────────────────────────────────────────────────────

variable "vnet_address_space" {
  description = "Lab VNet CIDR — kept outside the enterprise tree's 10.0/10.10/10.20 ranges"
  type        = string
  default     = "10.50.0.0/16"
}

variable "aks_subnet_prefix" {
  description = "Node subnet. With overlay mode this only needs to hold nodes, not pods."
  type        = string
  default     = "10.50.0.0/22"
}

variable "pod_cidr" {
  description = "Overlay pod CIDR. Not routable in the VNet; must not overlap it."
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "Kubernetes Service CIDR. Must not overlap the VNet or pod CIDR."
  type        = string
  default     = "10.51.0.0/16"
}

variable "dns_service_ip" {
  description = "kube-dns address — must sit inside service_cidr"
  type        = string
  default     = "10.51.0.10"
}

variable "common_tags" {
  description = "Tags applied to every resource"
  type        = map(string)
}
