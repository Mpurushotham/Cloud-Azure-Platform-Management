targetScope = 'resourceGroup'

@description('Azure region')
param location string = 'eastus'

@description('Key Vault name (must be globally unique, 3-24 chars)')
param keyVaultName string

@description('Environment')
param environment string

@description('Log Analytics workspace resource ID')
param logAnalyticsWorkspaceId string

@description('Private endpoint subnet resource ID')
param privateEndpointSubnetId string

@description('Private DNS zone resource ID for Key Vault (privatelink.vaultcore.azure.net)')
param keyVaultPrivateDnsZoneId string = ''

@description('Principal IDs to assign Key Vault Administrator role')
param keyVaultAdminPrincipalIds array = []

@description('Entra ID tenant ID')
param tenantId string = tenant().tenantId

// ─── Key Vault ────────────────────────────────────────────────────────────────
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'premium'
    }
    tenantId: tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
  }
  tags: {
    Environment: environment
    ManagedBy: 'platform-team'
    Application: 'platform-secrets'
    CostCenter: 'CC-PLATFORM'
    Owner: 'platform-team@contoso.com'
  }
}

// ─── RBAC: Key Vault Administrator ───────────────────────────────────────────
var kvAdminRoleId = '00482a5a-887f-4fb3-b363-3b7fe8e74483'
resource kvAdminAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in keyVaultAdminPrincipalIds: {
  name: guid(keyVault.id, principalId, kvAdminRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', kvAdminRoleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}]

// ─── Private Endpoint ────────────────────────────────────────────────────────
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-06-01' = {
  name: 'pe-${keyVaultName}'
  location: location
  properties: {
    subnet: { id: privateEndpointSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'pe-${keyVaultName}-connection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: ['vault']
          requestMessage: 'Auto-approved private endpoint'
        }
      }
    ]
  }
  tags: {
    Environment: environment
    ManagedBy: 'platform-team'
  }
}

// ─── Private DNS Zone Group ───────────────────────────────────────────────────
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-06-01' = if (!empty(keyVaultPrivateDnsZoneId)) {
  parent: privateEndpoint
  name: 'kvDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-vaultcore-azure-net'
        properties: {
          privateDnsZoneId: keyVaultPrivateDnsZoneId
        }
      }
    ]
  }
}

// ─── Diagnostic Settings ─────────────────────────────────────────────────────
resource kvDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${keyVaultName}'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { category: 'AuditEvent', enabled: true, retentionPolicy: { enabled: true, days: 365 } }
      { category: 'AzurePolicyEvaluationDetails', enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}

// ─── Outputs ─────────────────────────────────────────────────────────────────
output keyVaultId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri
output privateEndpointId string = privateEndpoint.id
