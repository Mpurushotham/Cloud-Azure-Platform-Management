variable "location" {
  type    = string
  default = "eastus"
}

variable "resource_group_name" {
  description = "Resource group for Key Vault and related security resources"
  type        = string
}

variable "key_vault_name" {
  description = "Key Vault name (globally unique, 3-24 chars, alphanumeric and hyphens)"
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Subnet resource ID for Key Vault private endpoint"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID for diagnostic settings"
  type        = string
}

variable "key_vault_admin_principal_ids" {
  description = "List of principal IDs to assign Key Vault Administrator role"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
