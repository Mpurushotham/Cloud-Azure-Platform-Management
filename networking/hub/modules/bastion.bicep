param location string
param bastionName string
param bastionSubnetId string
param environment string
param logAnalyticsWorkspaceId string

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: 'pip-${bastionName}'
  location: location
  sku: { name: 'Standard', tier: 'Regional' }
  zones: ['1', '2', '3']
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  tags: { Environment: environment, ManagedBy: 'platform-team' }
}

resource bastion 'Microsoft.Network/bastionHosts@2023-06-01' = {
  name: bastionName
  location: location
  sku: { name: 'Standard' }
  properties: {
    scaleUnits: 2
    enableShareableLink: true
    enableIpConnect: true
    enableTunneling: true
    enableFileCopy: true
    enableKerberos: false
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: bastionSubnetId }
          publicIPAddress: { id: bastionPublicIp.id }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
  tags: {
    Environment: environment
    ManagedBy: 'platform-team'
    Application: 'hub-connectivity'
    CostCenter: 'CC-PLATFORM'
    Owner: 'platform-team@contoso.com'
  }
}

resource bastionDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${bastionName}'
  scope: bastion
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { category: 'BastionAuditLogs', enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}

output bastionId string = bastion.id
output bastionPublicIp string = bastionPublicIp.properties.ipAddress
