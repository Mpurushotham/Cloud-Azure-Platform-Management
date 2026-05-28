targetScope = 'managementGroup'

@description('Location for deployment resources')
param location string = 'eastus'

@description('Log Analytics workspace resource ID for diagnostic data')
param logAnalyticsWorkspaceId string

@description('Allowed deployment locations')
param allowedLocations array = ['eastus', 'eastus2', 'westus2']

@description('Effect for tag enforcement policy')
@allowed(['Audit', 'Deny', 'Disabled'])
param tagEffect string = 'Deny'

@description('Effect for TLS enforcement policy')
@allowed(['Audit', 'Deny', 'Disabled'])
param tlsEffect string = 'Deny'

@description('Effect for public IP deny policy')
@allowed(['Audit', 'Deny', 'Disabled'])
param publicIpEffect string = 'Deny'

// ─── System-assigned identity for remediation tasks ──────────────────────────

// ─── Security Baseline Initiative Assignment ─────────────────────────────────
resource securityBaselineAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'security-baseline'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Enterprise Security Baseline'
    description: 'Assigns the security baseline initiative (MCSB-aligned) to this management group scope'
    policyDefinitionId: extensionResourceId(
      managementGroup().id,
      'Microsoft.Authorization/policySetDefinitions',
      'security-baseline-initiative'
    )
    parameters: {
      tlsEffect: { value: tlsEffect }
      encryptionEffect: { value: 'AuditIfNotExists' }
      publicIpEffect: { value: publicIpEffect }
    }
    enforcementMode: 'Default'
  }
}

// ─── Governance Baseline Initiative Assignment ────────────────────────────────
resource governanceBaselineAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'governance-baseline'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Enterprise Governance Baseline'
    description: 'Assigns the governance baseline initiative for tagging, naming, and location controls'
    policyDefinitionId: extensionResourceId(
      managementGroup().id,
      'Microsoft.Authorization/policySetDefinitions',
      'governance-baseline-initiative'
    )
    parameters: {
      tagEffect: { value: tagEffect }
      locationEffect: { value: 'Deny' }
      allowedLocations: { value: allowedLocations }
    }
    enforcementMode: 'Default'
  }
}

// ─── Deny Public IP (Corp MG — applied separately) ───────────────────────────
resource denyPublicIpAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'deny-public-ip'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Deny Public IP Creation'
    description: 'Prevents creation of public IPs in corp landing zone'
    policyDefinitionId: extensionResourceId(
      managementGroup().id,
      'Microsoft.Authorization/policyDefinitions',
      'deny-public-ip-creation'
    )
    parameters: {
      effect: { value: publicIpEffect }
    }
    enforcementMode: 'Default'
  }
}

// ─── Remediation Task for Security Baseline ─────────────────────────────────
resource securityBaselineRemediation 'Microsoft.PolicyInsights/remediations@2021-10-01' = {
  name: 'security-baseline-remediation'
  properties: {
    policyAssignmentId: securityBaselineAssignment.id
    resourceDiscoveryMode: 'ExistingNonCompliant'
    parallelDeployments: 10
    failureThreshold: {
      percentage: 0.1
    }
  }
}

// ─── Outputs ─────────────────────────────────────────────────────────────────
output securityBaselineAssignmentId string = securityBaselineAssignment.id
output governanceBaselineAssignmentId string = governanceBaselineAssignment.id
output denyPublicIpAssignmentId string = denyPublicIpAssignment.id
