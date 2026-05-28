targetScope = 'resourceGroup'

@description('Azure region')
param location string = 'eastus'

@description('Log Analytics workspace name')
param workspaceName string = 'law-platform-prod-001'

@description('Environment')
param environment string = 'prod'

@description('Interactive data retention in days (30-730)')
param retentionInDays int = 90

@description('Total data archive retention in days (max 4383 days = ~12 years)')
param totalRetentionInDays int = 365

@description('Daily ingestion quota in GB (-1 = unlimited)')
param dailyQuotaGb int = -1

// ─── Log Analytics Workspace ─────────────────────────────────────────────────
resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: retentionInDays
    features: {
      enableDataExport: true
      immediatePurgeDataOn30Days: false
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: dailyQuotaGb
    }
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: {
    Environment: environment
    ManagedBy: 'platform-team'
    Application: 'platform-monitoring'
    CostCenter: 'CC-PLATFORM'
    Owner: 'platform-team@contoso.com'
  }
}

// ─── Data Archive Policy (Workspace-level) ───────────────────────────────────
resource workspaceTableSecurityEvent 'Microsoft.OperationalInsights/workspaces/tables@2023-09-01' = {
  parent: workspace
  name: 'SecurityEvent'
  properties: {
    retentionInDays: 90
    totalRetentionInDays: totalRetentionInDays
  }
}

resource workspaceTableAzureActivity 'Microsoft.OperationalInsights/workspaces/tables@2023-09-01' = {
  parent: workspace
  name: 'AzureActivity'
  properties: {
    retentionInDays: 90
    totalRetentionInDays: totalRetentionInDays
  }
}

// ─── Solutions ────────────────────────────────────────────────────────────────
var solutions = [
  { name: 'VMInsights', product: 'OMSGallery/VMInsights', publisher: 'Microsoft' }
  { name: 'ContainerInsights', product: 'OMSGallery/ContainerInsights', publisher: 'Microsoft' }
  { name: 'ChangeTracking', product: 'OMSGallery/ChangeTracking', publisher: 'Microsoft' }
  { name: 'Updates', product: 'OMSGallery/Updates', publisher: 'Microsoft' }
  { name: 'AzureActivity', product: 'OMSGallery/AzureActivity', publisher: 'Microsoft' }
  { name: 'AgentHealthAssessment', product: 'OMSGallery/AgentHealthAssessment', publisher: 'Microsoft' }
]

resource workspaceSolutions 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = [for sol in solutions: {
  name: '${sol.name}(${workspaceName})'
  location: location
  plan: {
    name: '${sol.name}(${workspaceName})'
    publisher: sol.publisher
    product: sol.product
    promotionCode: ''
  }
  properties: {
    workspaceResourceId: workspace.id
  }
}]

// ─── Activity Log Diagnostic Setting (subscription-level) ───────────────────
resource activityLogDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-activity-log-to-law'
  scope: subscription()
  properties: {
    workspaceId: workspace.id
    logs: [
      {
        category: 'Administrative'
        enabled: true
        retentionPolicy: { enabled: true, days: 365 }
      }
      {
        category: 'Security'
        enabled: true
        retentionPolicy: { enabled: true, days: 365 }
      }
      {
        category: 'ServiceHealth'
        enabled: true
        retentionPolicy: { enabled: true, days: 90 }
      }
      {
        category: 'Alert'
        enabled: true
        retentionPolicy: { enabled: true, days: 90 }
      }
      {
        category: 'Recommendation'
        enabled: true
        retentionPolicy: { enabled: true, days: 90 }
      }
      {
        category: 'Policy'
        enabled: true
        retentionPolicy: { enabled: true, days: 365 }
      }
      {
        category: 'Autoscale'
        enabled: true
        retentionPolicy: { enabled: true, days: 90 }
      }
      {
        category: 'ResourceHealth'
        enabled: true
        retentionPolicy: { enabled: true, days: 90 }
      }
    ]
  }
}

// ─── Outputs ─────────────────────────────────────────────────────────────────
output workspaceId string = workspace.id
output workspaceName string = workspace.name
output workspaceCustomerId string = workspace.properties.customerId
output workspaceLocation string = workspace.location
