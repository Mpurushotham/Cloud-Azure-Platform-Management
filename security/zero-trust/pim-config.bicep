targetScope = 'managementGroup'

@description('Principal IDs for Platform Engineers group (eligible for Platform Engineer role)')
param platformEngineerGroupId string

@description('Principal IDs for Security Admins group (eligible for Security Admin role)')
param securityAdminGroupId string

@description('Entra ID tenant ID')
param tenantId string = tenant().tenantId

// ─── Built-in Role IDs for PIM Eligible Assignments ─────────────────────────
var ownerRoleId = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
var securityAdminRoleId = 'fb1c8493-542b-48eb-b624-b4c8fea62acd'

// ─── PIM Eligible Role Assignment: Platform Engineer → Owner (time-limited) ──
// NOTE: PIM eligible assignments use Microsoft.Authorization/roleEligibilityScheduleRequests
// This requires Azure AD Premium P2 and the Privileged Identity Management provider.

resource platformEngineerOwnerEligible 'Microsoft.Authorization/roleEligibilityScheduleRequests@2022-04-01-preview' = {
  name: guid(managementGroup().id, platformEngineerGroupId, ownerRoleId, 'eligible')
  properties: {
    principalId: platformEngineerGroupId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', ownerRoleId)
    requestType: 'AdminAssign'
    scheduleInfo: {
      startDateTime: '2024-01-01T00:00:00Z'
      expiration: {
        type: 'NoExpiration'
      }
    }
    ticketInfo: {
      ticketNumber: 'PLATFORM-001'
      ticketSystem: 'ServiceNow'
    }
    justification: 'Platform Engineering team requires eligible Owner access for emergency break-glass scenarios. Requires MFA + justification + approval to activate.'
  }
}

resource securityAdminEligible 'Microsoft.Authorization/roleEligibilityScheduleRequests@2022-04-01-preview' = {
  name: guid(managementGroup().id, securityAdminGroupId, securityAdminRoleId, 'eligible')
  properties: {
    principalId: securityAdminGroupId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', securityAdminRoleId)
    requestType: 'AdminAssign'
    scheduleInfo: {
      startDateTime: '2024-01-01T00:00:00Z'
      expiration: {
        type: 'NoExpiration'
      }
    }
    justification: 'Security team requires eligible Security Administrator access for incident response and policy management.'
  }
}

output platformEngineerEligibleId string = platformEngineerOwnerEligible.id
output securityAdminEligibleId string = securityAdminEligible.id
