targetScope = 'managementGroup'

@description('Principal ID of the Platform Engineers group in Entra ID')
param platformEngineerGroupId string

@description('Principal ID of the Network Operators group in Entra ID')
param networkOperatorGroupId string

@description('Principal ID of the Security Readers group in Entra ID')
param securityReaderGroupId string

@description('Principal ID of the GitHub Actions OIDC service principal')
param cicdServicePrincipalId string

// ─── Custom Role Definition IDs ─────────────────────────────────────────────
var platformEngineerRoleId = '00000000-0000-0000-0000-000000000001'
var networkOperatorRoleId  = '00000000-0000-0000-0000-000000000002'
var securityReaderRoleId   = '00000000-0000-0000-0000-000000000003'

// ─── Built-in Role IDs ───────────────────────────────────────────────────────
var readerRoleId            = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
var contributorRoleId       = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var securityAdminRoleId     = 'fb1c8493-542b-48eb-b624-b4c8fea62acd'

// ─── Platform Engineers: Platform Engineer role at current MG ───────────────
resource platformEngineerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(managementGroup().id, platformEngineerGroupId, platformEngineerRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', platformEngineerRoleId)
    principalId: platformEngineerGroupId
    principalType: 'Group'
    description: 'Platform Engineers — platform operations access'
  }
}

// ─── Security Readers: Security Reader role at root MG ──────────────────────
resource securityReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(managementGroup().id, securityReaderGroupId, securityReaderRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', securityReaderRoleId)
    principalId: securityReaderGroupId
    principalType: 'Group'
    description: 'Security team — read-only security posture access'
  }
}

// ─── Reader role for all teams at root MG (visibility) ──────────────────────
resource readerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(managementGroup().id, platformEngineerGroupId, readerRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
    principalId: platformEngineerGroupId
    principalType: 'Group'
    description: 'Reader access for all platform engineers at root MG for visibility'
  }
}

// ─── CI/CD Service Principal: Contributor at Landing Zones MG ───────────────
resource cicdContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(managementGroup().id, cicdServicePrincipalId, contributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalId: cicdServicePrincipalId
    principalType: 'ServicePrincipal'
    description: 'GitHub Actions OIDC — Contributor for IaC deployments'
  }
}

// ─── Outputs ─────────────────────────────────────────────────────────────────
output platformEngineerAssignmentId string = platformEngineerAssignment.id
output securityReaderAssignmentId string = securityReaderAssignment.id
