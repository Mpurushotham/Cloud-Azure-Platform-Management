targetScope = 'subscription'

@description('Azure region')
param location string = 'eastus'

@description('Environment')
@allowed(['prod', 'staging', 'dev'])
param environment string

@description('Workload name for this Corp landing zone')
param workloadName string

@description('Spoke VNet address prefix')
param spokeAddressPrefix string

@description('Hub VNet resource ID')
param hubVnetId string

@description('Azure Firewall private IP for default route')
param firewallPrivateIp string

@description('Log Analytics workspace resource ID')
param logAnalyticsWorkspaceId string

@description('DDoS Protection Plan resource ID')
param ddosPlanId string

var prefix = '${workloadName}-${environment}'

// ─── Spoke Networking ─────────────────────────────────────────────────────────
module spokeNetwork '../../networking/spoke/main.bicep' = {
  name: 'corp-spoke-network'
  params: {
    location: location
    environment: environment
    landingZoneType: 'corp'
    spokeAddressPrefix: spokeAddressPrefix
    hubVnetId: hubVnetId
    firewallPrivateIp: firewallPrivateIp
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    workloadName: workloadName
  }
}

// ─── Key Vault (per landing zone, for workload secrets) ───────────────────────
resource rgKeyVault 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: 'rg-spoke-${prefix}-${location}-001'
}

module workloadKeyVault '../../security/key-vault/main.bicep' = {
  name: 'corp-kv'
  scope: rgKeyVault
  params: {
    location: location
    keyVaultName: 'kv-${workloadName}-${environment}-001'
    environment: environment
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    privateEndpointSubnetId: spokeNetwork.outputs.privateEndpointSubnetId
  }
  dependsOn: [spokeNetwork]
}

// ─── Private DNS Zone for Key Vault ──────────────────────────────────────────
// (Central private DNS zones are managed in networking/private-dns; PE records
//  auto-register via A record creation on the private endpoint resource)

// ─── Defender for Cloud: subscription-level enrollment ───────────────────────
module defenderPlans '../../security/defender/main.bicep' = {
  name: 'corp-defender'
  params: {
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// ─── Budget ───────────────────────────────────────────────────────────────────
module budget '../../finops/budgets/main.bicep' = {
  name: 'corp-budget'
  params: {
    environment: environment
    workloadName: workloadName
    notificationEmailAddress: 'workload-team@contoso.com'
  }
}

// ─── Outputs ─────────────────────────────────────────────────────────────────
output spokeVnetId string = spokeNetwork.outputs.spokeVnetId
output appSubnetId string = spokeNetwork.outputs.appSubnetId
output dataSubnetId string = spokeNetwork.outputs.dataSubnetId
output keyVaultId string = workloadKeyVault.outputs.keyVaultId
