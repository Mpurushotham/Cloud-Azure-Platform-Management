variable "location" {
  type    = string
  default = "eastus"
}

variable "resource_group_name" {
  type = string
}

variable "workspace_name" {
  description = "Log Analytics workspace name"
  type        = string
}

variable "environment" {
  type = string
}

variable "retention_days" {
  description = "Interactive data retention in days (30-730)"
  type        = number
  default     = 90
}

variable "alert_email_addresses" {
  description = "List of email addresses for alert notifications"
  type        = list(string)
  default     = ["platform-team@contoso.com"]
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
