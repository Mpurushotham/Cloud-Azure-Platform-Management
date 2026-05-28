targetScope = 'managementGroup'

@description('Location for deployment resources')
param location string = 'eastus'

@description('Effect for tag enforcement (Deny recommended for production)')
@allowed(['Audit', 'Deny', 'Disabled'])
param tagEffect string = 'Deny'

// ─── Required Tags Policy Assignment ─────────────────────────────────────────
resource requireTagsAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'require-mandatory-tags'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Require Mandatory Tags on All Resources'
    description: 'Enforces Environment, CostCenter, Owner, Application, ManagedBy tags on all resources'
    policyDefinitionId: extensionResourceId(
      managementGroup().id,
      'Microsoft.Authorization/policyDefinitions',
      'require-mandatory-tags'
    )
    parameters: {
      effect: { value: tagEffect }
    }
    enforcementMode: 'Default'
  }
}

// ─── Inherit Environment Tag from Resource Group ──────────────────────────────
resource inheritEnvironmentTag 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'inherit-environment-tag'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Inherit Environment Tag from Resource Group'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/9ea02ca2-71db-412d-8b00-7c7ca9fcd32d'
    parameters: {
      tagName: { value: 'Environment' }
    }
    enforcementMode: 'Default'
  }
}

// ─── Inherit CostCenter Tag from Resource Group ───────────────────────────────
resource inheritCostCenterTag 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'inherit-costcenter-tag'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Inherit CostCenter Tag from Resource Group'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/9ea02ca2-71db-412d-8b00-7c7ca9fcd32d'
    parameters: {
      tagName: { value: 'CostCenter' }
    }
    enforcementMode: 'Default'
  }
}

output requireTagsAssignmentId string = requireTagsAssignment.id
