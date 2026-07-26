// ─── Policy definitions, at SUBSCRIPTION scope ───────────────────────────────
// The enterprise tree has no subscription-scoped policy at all: every
// definition in governance/policies/custom/ is created at a management group by
// scripts/powershell/Setup-Governance.ps1, and every assignment in
// governance/policies/assignments/main.bicep is targetScope = 'managementGroup'.
// With no management-group access, none of it is reachable — hence these.
//
// Omitting management_group_id creates the definition in the provider's
// subscription. Each one below fixes a defect in its enterprise counterpart;
// the differences are called out inline.

resource "azurerm_policy_definition" "require_tags" {
  name         = "lab-require-mandatory-tags"
  policy_type  = "Custom"
  mode         = "Indexed" // skips resource groups and non-taggable types
  display_name = "Lab — require mandatory tags"
  description  = "Denies resources missing any of the five mandatory tags."

  metadata = jsonencode({ category = "Tags", version = "1.0.0" })

  parameters = jsonencode({
    effect = {
      type          = "String"
      defaultValue  = "Audit"
      allowedValues = ["Audit", "Deny", "Disabled"]
      metadata      = { displayName = "Effect" }
    }
  })

  // Differs from governance/policies/custom/require-tags.json in that its
  // defaultValue is "Audit", not "Deny". A Deny that ships enabled by default
  // is how you brick a subscription on first assignment.
  //
  // The tag list is expanded by TERRAFORM, not by an Azure Policy parameter.
  // The obvious dynamic form —
  //     count.where.value = "[empty(field(concat('tags[', current('tagName'), ']')))]"
  // — is rejected at definition time:
  //     InvalidPolicyParameters: 'FIELD' functions cannot contain additional
  //     runtime functions: ... CURRENT ...
  // Azure Policy will not let field() take a name computed at evaluation time.
  // Generating the conditions in HCL keeps the list configurable (var.required_tags)
  // while emitting exactly the static shape Policy accepts.
  policy_rule = jsonencode({
    if = {
      anyOf = [
        for t in var.required_tags : { field = "tags['${t}']", exists = "false" }
      ]
    }
    then = { effect = "[parameters('effect')]" }
  })
}

resource "azurerm_policy_definition" "allowed_locations" {
  name         = "lab-allowed-locations"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Lab — allowed resource locations"
  description  = "Restricts the regions resources may be deployed into."

  metadata = jsonencode({ category = "General", version = "1.0.0" })

  parameters = jsonencode({
    effect = {
      type          = "String"
      defaultValue  = "Audit"
      allowedValues = ["Audit", "Deny", "Disabled"]
      metadata      = { displayName = "Effect" }
    }
    allowedLocations = {
      type         = "Array"
      defaultValue = ["eastus"]
      metadata     = { displayName = "Allowed locations", strongType = "location" }
    }
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        { field = "location", notIn = "[parameters('allowedLocations')]" },
        { field = "location", notEquals = "global" },
        { field = "type", notEquals = "Microsoft.AzureActiveDirectory/b2cDirectories" }
      ]
    }
    then = { effect = "[parameters('effect')]" }
  })
}

resource "azurerm_policy_definition" "deny_public_ip" {
  name         = "lab-deny-public-ip"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Lab — restrict public IP addresses"
  description  = "Audits or denies creation of public IP addresses."

  metadata = jsonencode({ category = "Network", version = "1.0.0" })

  parameters = jsonencode({
    effect = {
      type          = "String"
      defaultValue  = "Audit"
      allowedValues = ["Audit", "Deny", "Disabled"]
      metadata      = { displayName = "Effect" }
    }
  })

  // governance/policies/custom/deny-public-ip.json matches ALL public IPs
  // unconditionally, and its description claims an App Gateway exception that
  // does not exist in the rule. This is the single control most likely to break
  // AKS: with outboundType = loadBalancer the cluster creates an egress public
  // IP in its MC_* node resource group, and denying it fails cluster creation
  // with an opaque reconcile error that never mentions policy.
  //
  // The rule is left deliberately broad — the point of Phase 3 is to observe
  // that breakage under DoNotEnforce, then decide between a not_scopes
  // exclusion and changing the workload. See assignments.tf.
  policy_rule = jsonencode({
    if = {
      field  = "type"
      equals = "Microsoft.Network/publicIPAddresses"
    }
    then = { effect = "[parameters('effect')]" }
  })
}

resource "azurerm_policy_definition" "enforce_tls" {
  name         = "lab-enforce-tls-minimum"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Lab — enforce minimum TLS version"
  description  = "Requires storage accounts to accept TLS 1.2 or above."

  metadata = jsonencode({ category = "Security", version = "1.0.0" })

  parameters = jsonencode({
    effect = {
      type          = "String"
      defaultValue  = "Audit"
      allowedValues = ["Audit", "Deny", "Disabled"]
      metadata      = { displayName = "Effect" }
    }
  })

  // Fixes a real bug in governance/policies/custom/enforce-tls.json, which
  // tests `notEquals "TLS1_2"`. That is an equality check masquerading as a
  // floor, so it *denies TLS 1.3* — a stricter, better configuration — and,
  // because a non-existent field satisfies notEquals, it also denies any
  // storage account that simply omits the property and inherits the platform
  // default. Using notIn with an explicit allow-list of acceptable versions
  // expresses "1.2 or better" correctly.
  policy_rule = jsonencode({
    if = {
      allOf = [
        { field = "type", equals = "Microsoft.Storage/storageAccounts" },
        { field = "Microsoft.Storage/storageAccounts/minimumTlsVersion", notIn = ["TLS1_2", "TLS1_3"] }
      ]
    }
    then = { effect = "[parameters('effect')]" }
  })
}
