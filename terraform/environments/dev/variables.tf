variable "subscription_id" {
  type = string
}

variable "hub_address_prefix" {
  type    = string
  default = "10.2.0.0/16"
}

variable "alert_email_addresses" {
  type    = list(string)
  default = ["platform-team@contoso.com"]
}
