targetScope = 'resourceGroup'

@description('Hub VNet resource ID to link all private DNS zones')
param hubVnetId string

@description('Environment')
param environment string = 'prod'

// ─── Private DNS Zone definitions ────────────────────────────────────────────
var privateDnsZones = [
  'privatelink.blob.core.windows.net'
  'privatelink.queue.core.windows.net'
  'privatelink.table.core.windows.net'
  'privatelink.file.core.windows.net'
  'privatelink.dfs.core.windows.net'
  'privatelink.vaultcore.azure.net'
  'privatelink.database.windows.net'
  'privatelink.postgres.database.azure.com'
  'privatelink.mysql.database.azure.com'
  'privatelink.documents.azure.com'
  'privatelink.azurecr.io'
  'privatelink.aks.azure.com'
  'privatelink.servicebus.windows.net'
  'privatelink.eventgrid.azure.net'
  'privatelink.azurewebsites.net'
  'privatelink.redis.cache.windows.net'
  'privatelink.search.windows.net'
  'privatelink.monitor.azure.com'
  'privatelink.oms.opinsights.azure.com'
  'privatelink.ods.opinsights.azure.com'
  'privatelink.agentsvc.azure-automation.net'
  'privatelink.cognitiveservices.azure.com'
  'privatelink.openai.azure.com'
]

// ─── Deploy each Private DNS Zone ────────────────────────────────────────────
resource dnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for zone in privateDnsZones: {
  name: zone
  location: 'global'
  tags: {
    Environment: environment
    ManagedBy: 'platform-team'
    Application: 'hub-connectivity'
    CostCenter: 'CC-PLATFORM'
    Owner: 'platform-team@contoso.com'
  }
}]

// ─── Link each zone to the Hub VNet ─────────────────────────────────────────
resource dnsZoneVnetLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (zone, i) in privateDnsZones: {
  parent: dnsZones[i]
  name: 'link-${replace(zone, '.', '-')}-hub'
  location: 'global'
  properties: {
    virtualNetwork: { id: hubVnetId }
    registrationEnabled: false
  }
}]

// ─── Outputs ─────────────────────────────────────────────────────────────────
output blobDnsZoneId string = dnsZones[0].id
output keyVaultDnsZoneId string = dnsZones[5].id
output sqlDnsZoneId string = dnsZones[7].id
output acrDnsZoneId string = dnsZones[11].id
output aksDnsZoneId string = dnsZones[12].id
