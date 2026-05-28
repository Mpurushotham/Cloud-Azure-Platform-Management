# Production Environment Variables
# Replace <prod-subscription-id> with actual subscription ID before deploying.
# This file does NOT contain secrets — sensitive values use OIDC or Key Vault references.

subscription_id = "<prod-subscription-id>"

hub_address_prefix = "10.0.0.0/16"

alert_email_addresses = [
  "platform-team@contoso.com",
  "sre-oncall@contoso.com"
]
