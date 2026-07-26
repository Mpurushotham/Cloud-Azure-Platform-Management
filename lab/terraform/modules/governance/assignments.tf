// ─── Initiative + subscription assignment ────────────────────────────────────

resource "azurerm_policy_set_definition" "lab_baseline" {
  name         = "lab-baseline-initiative"
  policy_type  = "Custom"
  display_name = "Lab — governance baseline"
  description  = "Tags, locations, public IP and TLS controls for the lab subscription."

  metadata = jsonencode({ category = "Lab", version = "1.0.0" })

  parameters = jsonencode({
    tagEffect      = { type = "String", defaultValue = "Audit" }
    locationEffect = { type = "String", defaultValue = "Audit" }
    publicIpEffect = { type = "String", defaultValue = "Audit" }
    tlsEffect      = { type = "String", defaultValue = "Audit" }
    allowedLocations = {
      type         = "Array"
      defaultValue = ["eastus"]
    }
  })

  // Definition IDs are referenced from the resources themselves, not hardcoded.
  // governance/policies/initiatives/*.json hardcode
  // /providers/Microsoft.Management/managementGroups/Contoso/... paths, which
  // resolve in exactly one tenant — one named "Contoso".
  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.require_tags.id
    reference_id         = "RequireMandatoryTags"
    parameter_values     = jsonencode({ effect = { value = "[parameters('tagEffect')]" } })
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.allowed_locations.id
    reference_id         = "AllowedLocations"
    parameter_values = jsonencode({
      effect           = { value = "[parameters('locationEffect')]" }
      allowedLocations = { value = "[parameters('allowedLocations')]" }
    })
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.deny_public_ip.id
    reference_id         = "RestrictPublicIp"
    parameter_values     = jsonencode({ effect = { value = "[parameters('publicIpEffect')]" } })
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.enforce_tls.id
    reference_id         = "EnforceTls"
    parameter_values     = jsonencode({ effect = { value = "[parameters('tlsEffect')]" } })
  }
}

// ─── The assignment ──────────────────────────────────────────────────────────
// enforce = false maps to enforcementMode "DoNotEnforce": Azure evaluates
// compliance and reports it, but does not block anything. This is the whole
// discipline of Phase 3 — see what a control WOULD reject before it can reject
// it. The enterprise assignments (governance/policies/assignments/main.bicep)
// all ship enforcementMode 'Default' with Deny effects and no notScopes, which
// is why they would break AKS on contact.
resource "azurerm_subscription_policy_assignment" "lab_baseline" {
  name                 = "lab-baseline"
  display_name         = "Lab governance baseline"
  description          = "Audit-first baseline. Flip effects to Deny only after reviewing compliance."
  subscription_id      = var.subscription_scope_id
  policy_definition_id = azurerm_policy_set_definition.lab_baseline.id

  enforce = var.enforce

  // AKS creates resources in its MC_* node resource group that you do not
  // control: load balancers, NSGs, route tables, the egress public IP, and CSI
  // provisioned disks. They are frequently untagged, and denying them fails
  // cluster operations in ways whose errors never mention policy. Excluding
  // that scope is the standard, honest resolution — the alternative is to
  // weaken the policy for everyone.
  not_scopes = var.excluded_scope_ids

  parameters = jsonencode({
    tagEffect        = { value = var.tag_effect }
    locationEffect   = { value = var.location_effect }
    publicIpEffect   = { value = var.public_ip_effect }
    tlsEffect        = { value = var.tls_effect }
    allowedLocations = { value = var.allowed_locations }
  })

  // A system-assigned identity is only required for Modify / DeployIfNotExists
  // effects. None of these four use them, so requesting one would be cargo
  // cult — the enterprise templates request an identity for every assignment
  // and then never create the role assignments it would need, so remediation
  // could not work even if it were reached.
  lifecycle {
    precondition {
      condition     = !(var.enforce && var.public_ip_effect == "Deny" && length(var.excluded_scope_ids) == 0)
      error_message = "Refusing to enforce publicIpEffect=Deny with no not_scopes: this denies the AKS egress public IP and will break the cluster. Pass the MC_* resource group id in excluded_scope_ids, or keep enforce=false."
    }
  }
}
