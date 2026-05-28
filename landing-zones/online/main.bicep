targetScope = 'subscription'

@description('Azure region')
param location string = 'eastus'

@description('Environment')
@allowed(['prod', 'staging', 'dev'])
param environment string

@description('Workload name for this Online landing zone')
param workloadName string

@description('Spoke VNet address prefix')
param spokeAddressPrefix string

@description('Hub VNet resource ID')
param hubVnetId string

@description('Azure Firewall private IP')
param firewallPrivateIp string

@description('Log Analytics workspace resource ID')
param logAnalyticsWorkspaceId string

var prefix = '${workloadName}-${environment}'
var rgName = 'rg-spoke-${prefix}-${location}-001'

// ─── Spoke Networking ─────────────────────────────────────────────────────────
module spokeNetwork '../../networking/spoke/main.bicep' = {
  name: 'online-spoke-network'
  params: {
    location: location
    environment: environment
    landingZoneType: 'online'
    spokeAddressPrefix: spokeAddressPrefix
    hubVnetId: hubVnetId
    firewallPrivateIp: firewallPrivateIp
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    workloadName: workloadName
  }
}

// ─── Application Gateway WAF v2 ───────────────────────────────────────────────
resource rgOnline 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: rgName
}

module appGateway 'modules/app-gateway.bicep' = {
  name: 'online-appgw'
  scope: rgOnline
  params: {
    location: location
    appGwName: 'appgw-${prefix}-001'
    environment: environment
    appSubnetId: spokeNetwork.outputs.appSubnetId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
  dependsOn: [spokeNetwork]
}

// ─── Defender for Cloud ───────────────────────────────────────────────────────
module defenderPlans '../../security/defender/main.bicep' = {
  name: 'online-defender'
  params: {
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// ─── Budget ───────────────────────────────────────────────────────────────────
module budget '../../finops/budgets/main.bicep' = {
  name: 'online-budget'
  params: {
    environment: environment
    workloadName: workloadName
    notificationEmailAddress: 'workload-team@contoso.com'
  }
}

// ─── Outputs ─────────────────────────────────────────────────────────────────
output spokeVnetId string = spokeNetwork.outputs.spokeVnetId
output appGatewayPublicIp string = appGateway.outputs.appGwPublicIp
output appSubnetId string = spokeNetwork.outputs.appSubnetId
