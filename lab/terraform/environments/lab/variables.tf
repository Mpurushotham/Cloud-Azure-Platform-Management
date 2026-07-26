variable "subscription_id" {
  description = "Target subscription ID. No default on purpose — an accidental apply against the wrong subscription is the one mistake with a real bill attached."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a GUID. Get it with: az account show --query id -o tsv"
  }
}

variable "owner_email" {
  description = "Your email — becomes the Owner tag and future alert target"
  type        = string
}

variable "location" {
  description = "Azure region. eastus has the 4 vCPU quota and is in the enterprise tree's allowedLocations."
  type        = string
  default     = "eastus"

  validation {
    condition     = contains(["eastus", "eastus2", "westus2"], var.location)
    error_message = "Stick to eastus/eastus2/westus2 — the only regions governance/policies/custom/allowed-locations.json permits by default."
  }
}

variable "location_abbrev" {
  description = "Short region code for names (eus, eus2, wus2) — see docs/architecture/landing-zone-design.md"
  type        = string
  default     = "eus"
}

variable "node_count" {
  description = "AKS node count. Keep at 1 — quota is 4 vCPU total."
  type        = number
  default     = 1
}

variable "node_vm_size" {
  description = "AKS node SKU. Standard_D2as_v7 = 2 vCPU / 8 GiB (~$0.09/hr). Burstable B-series is NOT offered to this subscription — see modules/cluster/variables.tf."
  type        = string
  default     = "Standard_D2as_v7"
}

variable "retention_days" {
  description = "Log Analytics retention in days"
  type        = number
  default     = 30
}

variable "daily_quota_gb" {
  description = "Log Analytics daily ingestion cap in GB — a hard spend guard"
  type        = number
  default     = 1
}

// ─── Policy effects (Phase 3) ────────────────────────────────────────────────
// Default posture is audit-only. Promote controls to Deny ONE AT A TIME, so a
// failed deployment points at a single control rather than four.

variable "policy_enforce" {
  description = "false => enforcementMode DoNotEnforce. Leave false until you have reviewed compliance."
  type        = bool
  default     = false
}

variable "policy_tag_effect" {
  description = "Effect for the mandatory-tags control"
  type        = string
  default     = "Audit"
}

variable "policy_location_effect" {
  description = "Effect for the allowed-locations control"
  type        = string
  default     = "Audit"
}

variable "policy_public_ip_effect" {
  description = "Effect for the public-IP control. Deny here is what breaks AKS."
  type        = string
  default     = "Audit"
}

variable "policy_tls_effect" {
  description = "Effect for the minimum-TLS control"
  type        = string
  default     = "Audit"
}
