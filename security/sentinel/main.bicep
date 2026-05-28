targetScope = 'resourceGroup'

@description('Azure region')
param location string = 'eastus'

@description('Log Analytics workspace name (will be created if not existing)')
param workspaceName string = 'law-sentinel-prod-001'

@description('Environment')
param environment string = 'prod'

@description('Log Analytics daily cap in GB (-1 = no cap)')
param dailyQuotaGb int = -1

// ─── Log Analytics Workspace (Sentinel tier) ─────────────────────────────────
resource sentinelWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 90
    workspaceCapping: {
      dailyQuotaGb: dailyQuotaGb
    }
    features: {
      enableDataExport: true
      immediatePurgeDataOn30Days: false
    }
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: {
    Environment: environment
    ManagedBy: 'security-team'
    Application: 'microsoft-sentinel'
    CostCenter: 'CC-SECURITY'
    Owner: 'security-team@contoso.com'
  }
}

// ─── Enable Microsoft Sentinel ────────────────────────────────────────────────
resource sentinel 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'SecurityInsights(${workspaceName})'
  location: location
  plan: {
    name: 'SecurityInsights(${workspaceName})'
    publisher: 'Microsoft'
    product: 'OMSGallery/SecurityInsights'
    promotionCode: ''
  }
  properties: {
    workspaceResourceId: sentinelWorkspace.id
  }
}

// ─── Data Connectors ─────────────────────────────────────────────────────────
resource connectorAzureActivity 'Microsoft.SecurityInsights/dataConnectors@2023-02-01-preview' = {
  scope: sentinelWorkspace
  name: guid(sentinelWorkspace.id, 'AzureActivity')
  kind: 'AzureActivity'
  properties: {
    linkedResourceId: '/subscriptions/${subscription().subscriptionId}/providers/microsoft.insights/eventtypes/management'
  }
  dependsOn: [sentinel]
}

resource connectorDefender 'Microsoft.SecurityInsights/dataConnectors@2023-02-01-preview' = {
  scope: sentinelWorkspace
  name: guid(sentinelWorkspace.id, 'MicrosoftCloudAppSecurity')
  kind: 'MicrosoftCloudAppSecurity'
  properties: {
    dataTypes: {
      alerts: { state: 'Enabled' }
      discoveryLogs: { state: 'Enabled' }
    }
    tenantId: tenant().tenantId
  }
  dependsOn: [sentinel]
}

resource connectorAzureAD 'Microsoft.SecurityInsights/dataConnectors@2023-02-01-preview' = {
  scope: sentinelWorkspace
  name: guid(sentinelWorkspace.id, 'AzureActiveDirectory')
  kind: 'AzureActiveDirectory'
  properties: {
    dataTypes: {
      alerts: { state: 'Enabled' }
    }
    tenantId: tenant().tenantId
  }
  dependsOn: [sentinel]
}

// ─── Analytics Rules ──────────────────────────────────────────────────────────

resource ruleImpossibleTravel 'Microsoft.SecurityInsights/alertRules@2023-02-01-preview' = {
  scope: sentinelWorkspace
  name: guid(sentinelWorkspace.id, 'impossible-travel')
  kind: 'Scheduled'
  properties: {
    displayName: 'Impossible Travel - Sign-in from Multiple Geographies'
    description: 'Detects a user signing in from two geographically distant locations within a short timeframe, indicating potential account compromise.'
    severity: 'High'
    enabled: true
    query: '''
      let timeRange = 1h;
      let distanceThreshold = 500;
      SigninLogs
      | where TimeGenerated > ago(timeRange)
      | where ResultType == "0"
      | project UserPrincipalName, Location, IPAddress, TimeGenerated, AppDisplayName
      | join kind=inner (
          SigninLogs
          | where TimeGenerated > ago(timeRange)
          | where ResultType == "0"
          | project UserPrincipalName, Location2 = Location, IPAddress2 = IPAddress, TimeGenerated2 = TimeGenerated
      ) on UserPrincipalName
      | where TimeGenerated2 > TimeGenerated
      | where Location != Location2
      | project UserPrincipalName, Location, Location2, IPAddress, IPAddress2, TimeGenerated, TimeGenerated2
      | summarize count() by UserPrincipalName, Location, Location2
    '''
    queryFrequency: 'PT1H'
    queryPeriod: 'PT1H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionDuration: 'PT1H'
    suppressionEnabled: false
    tactics: ['InitialAccess', 'CredentialAccess']
    techniques: ['T1078']
    incidentConfiguration: {
      createIncident: true
      groupingConfiguration: {
        enabled: true
        reopenClosedIncident: false
        lookbackDuration: 'PT5H'
        matchingMethod: 'AllEntities'
        groupByEntities: ['Account']
        groupByAlertDetails: []
        groupByCustomDetails: []
      }
    }
    entityMappings: [
      {
        entityType: 'Account'
        fieldMappings: [
          { identifier: 'FullName', columnName: 'UserPrincipalName' }
        ]
      }
    ]
  }
  dependsOn: [sentinel]
}

resource ruleBruteForce 'Microsoft.SecurityInsights/alertRules@2023-02-01-preview' = {
  scope: sentinelWorkspace
  name: guid(sentinelWorkspace.id, 'brute-force')
  kind: 'Scheduled'
  properties: {
    displayName: 'Brute Force Attack - Multiple Failed Sign-in Attempts'
    description: 'Detects multiple failed sign-in attempts to the same account within a short period, indicating a brute force attack.'
    severity: 'Medium'
    enabled: true
    query: '''
      SigninLogs
      | where TimeGenerated > ago(1h)
      | where ResultType != "0"
      | summarize FailedAttempts = count(), SourceIPs = make_set(IPAddress) by UserPrincipalName, bin(TimeGenerated, 5m)
      | where FailedAttempts >= 10
      | project UserPrincipalName, FailedAttempts, SourceIPs, TimeGenerated
    '''
    queryFrequency: 'PT1H'
    queryPeriod: 'PT1H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionDuration: 'PT30M'
    suppressionEnabled: false
    tactics: ['CredentialAccess']
    techniques: ['T1110']
    incidentConfiguration: {
      createIncident: true
      groupingConfiguration: {
        enabled: true
        reopenClosedIncident: false
        lookbackDuration: 'PT2H'
        matchingMethod: 'AllEntities'
        groupByEntities: ['Account']
        groupByAlertDetails: []
        groupByCustomDetails: []
      }
    }
    entityMappings: [
      {
        entityType: 'Account'
        fieldMappings: [
          { identifier: 'FullName', columnName: 'UserPrincipalName' }
        ]
      }
    ]
  }
  dependsOn: [sentinel]
}

resource rulePrivilegeEscalation 'Microsoft.SecurityInsights/alertRules@2023-02-01-preview' = {
  scope: sentinelWorkspace
  name: guid(sentinelWorkspace.id, 'privilege-escalation')
  kind: 'Scheduled'
  properties: {
    displayName: 'Privilege Escalation - New Global Admin or Privileged Role Assignment'
    description: 'Detects when a new Global Administrator, Privileged Role Administrator, or Security Administrator role is assigned in Entra ID.'
    severity: 'High'
    enabled: true
    query: '''
      AuditLogs
      | where TimeGenerated > ago(1h)
      | where OperationName == "Add member to role"
      | where Result == "success"
      | extend RoleName = tostring(TargetResources[0].displayName)
      | where RoleName in ("Global Administrator", "Privileged Role Administrator", "Security Administrator", "User Access Administrator")
      | project TimeGenerated, InitiatedBy = tostring(InitiatedBy.user.userPrincipalName), RoleName, TargetUser = tostring(TargetResources[1].userPrincipalName)
    '''
    queryFrequency: 'PT1H'
    queryPeriod: 'PT1H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionDuration: 'PT1H'
    suppressionEnabled: false
    tactics: ['PrivilegeEscalation']
    techniques: ['T1078']
    incidentConfiguration: {
      createIncident: true
      groupingConfiguration: {
        enabled: false
        reopenClosedIncident: false
        lookbackDuration: 'PT5H'
        matchingMethod: 'AllEntities'
        groupByEntities: []
        groupByAlertDetails: []
        groupByCustomDetails: []
      }
    }
  }
  dependsOn: [sentinel]
}

// ─── Outputs ─────────────────────────────────────────────────────────────────
output workspaceId string = sentinelWorkspace.id
output workspaceName string = sentinelWorkspace.name
output workspaceCustomerId string = sentinelWorkspace.properties.customerId
