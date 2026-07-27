output "assignment_id" {
  description = "Policy assignment resource ID — use with az policy state list --filter"
  value       = azurerm_subscription_policy_assignment.lab_baseline.id
}

output "assignment_name" {
  description = "Policy assignment name"
  value       = azurerm_subscription_policy_assignment.lab_baseline.name
}

output "initiative_id" {
  description = "Policy set (initiative) resource ID"
  value       = azurerm_policy_set_definition.lab_baseline.id
}

output "enforcement_mode" {
  description = "Human-readable enforcement state"
  value       = var.enforce ? "Default (ENFORCING — denies apply)" : "DoNotEnforce (audit only)"
}

output "effects" {
  description = "Current effect per control"
  value = {
    tags       = var.tag_effect
    locations  = var.location_effect
    public_ip  = var.public_ip_effect
    tls        = var.tls_effect
    not_scopes = length(var.excluded_scope_ids)
  }
}
