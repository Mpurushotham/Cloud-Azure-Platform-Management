variable "subscription_scope_id" {
  description = "Subscription resource ID to assign the initiative at (/subscriptions/<guid>)"
  type        = string
}

variable "enforce" {
  description = "false => enforcementMode DoNotEnforce (evaluate and report only). Start here, always."
  type        = bool
  default     = false
}

// ─── Per-control effects ─────────────────────────────────────────────────────
// Separate knobs so controls can be promoted to Deny one at a time. Promoting
// them together makes it impossible to tell which one broke a deployment.

variable "tag_effect" {
  description = "Effect for the mandatory-tags control"
  type        = string
  default     = "Audit"

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.tag_effect)
    error_message = "tag_effect must be Audit, Deny or Disabled."
  }
}

variable "location_effect" {
  description = "Effect for the allowed-locations control"
  type        = string
  default     = "Audit"

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.location_effect)
    error_message = "location_effect must be Audit, Deny or Disabled."
  }
}

variable "public_ip_effect" {
  description = "Effect for the public-IP control. Deny breaks AKS unless the MC_* group is in excluded_scope_ids."
  type        = string
  default     = "Audit"

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.public_ip_effect)
    error_message = "public_ip_effect must be Audit, Deny or Disabled."
  }
}

variable "tls_effect" {
  description = "Effect for the minimum-TLS control"
  type        = string
  default     = "Audit"

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.tls_effect)
    error_message = "tls_effect must be Audit, Deny or Disabled."
  }
}

variable "allowed_locations" {
  description = "Regions resources may be created in"
  type        = list(string)
  default     = ["eastus"]
}

variable "excluded_scope_ids" {
  description = "Scopes exempted from the assignment (not_scopes) — typically the AKS MC_* node resource group"
  type        = list(string)
  default     = []
}

variable "required_tags" {
  description = "Tag names the require-tags control checks for. Expanded into static policy conditions by Terraform, because Azure Policy rejects field() names computed at evaluation time."
  type        = list(string)
  default     = ["Environment", "CostCenter", "Owner", "Application", "ManagedBy"]

  validation {
    condition     = length(var.required_tags) > 0
    error_message = "required_tags must list at least one tag."
  }
}
