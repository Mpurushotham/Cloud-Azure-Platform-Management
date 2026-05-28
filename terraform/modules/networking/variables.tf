variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

variable "location_abbrev" {
  description = "Short location abbreviation for resource naming"
  type        = string
  default     = "eus"
}

variable "environment" {
  description = "Deployment environment (prod, staging, dev)"
  type        = string
  validation {
    condition     = contains(["prod", "staging", "dev"], var.environment)
    error_message = "Environment must be prod, staging, or dev."
  }
}

variable "workload_name" {
  description = "Workload or platform name for resource naming"
  type        = string
  default     = "platform"
}

variable "hub_address_prefix" {
  description = "Hub VNet address space (e.g. 10.0.0.0/16)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_ddos_protection" {
  description = "Enable Azure DDoS Network Protection Plan on hub VNet"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID for diagnostic settings"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy   = "platform-team"
    CostCenter  = "CC-PLATFORM"
    Owner       = "platform-team@contoso.com"
  }
}
