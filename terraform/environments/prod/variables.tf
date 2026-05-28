variable "subscription_id" {
  description = "Azure Subscription ID for production environment"
  type        = string
}

variable "hub_address_prefix" {
  description = "Hub VNet address prefix"
  type        = string
  default     = "10.0.0.0/16"
}

variable "alert_email_addresses" {
  description = "Email addresses for critical platform alerts"
  type        = list(string)
  default     = ["platform-team@contoso.com", "sre-oncall@contoso.com"]
}
