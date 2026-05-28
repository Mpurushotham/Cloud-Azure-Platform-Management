targetScope = 'subscription'

@description('Azure region')
param location string = 'eastus'

@description('Environment')
@allowed(['prod', 'staging', 'dev', 'sandbox'])
param environment string

@description('Landing zone type — determines which policies and connectivity apply')
@allowed(['corp', 'online', 'sandbox'])
param landingZoneType string

@description('Spoke VNet address prefix (e.g. 10.10.0.0/16)')
param spokeAddressPrefix string

@description('Hub VNet resource ID for peering')
param hubVnetId string

@description('Azure Firewall private IP for default route')
param firewallPrivateIp string

@description('Log Analytics workspace resource ID')
param logAnalyticsWorkspaceId string

@description('Workload name for resource naming')
param workloadName string

var prefix = '${workloadName}-${environment}'
var rgName = 'rg-spoke-${prefix}-${location}-001'

// ─── Resource Group ───────────────────────────────────────────────────────────
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: rgName
  location: location
  tags: {
    Environment: environment
    ManagedBy: 'platform-team'
    Application: workloadName
    CostCenter: 'CC-WORKLOAD'
    Owner: 'workload-team@contoso.com'
  }
}

// ─── NSGs ─────────────────────────────────────────────────────────────────────
module nsgs 'modules/nsgs.bicep' = {
  name: 'spoke-nsgs'
  scope: rg
  params: {
    location: location
    environment: environment
    prefix: prefix
    landingZoneType: landingZoneType
  }
}

// ─── Route Table (force tunnel to firewall) ───────────────────────────────────
module routeTable 'modules/route-table.bicep' = {
  name: 'spoke-route-table'
  scope: rg
  params: {
    location: location
    prefix: prefix
    firewallPrivateIp: firewallPrivateIp
    environment: environment
  }
}

// ─── Spoke VNet ───────────────────────────────────────────────────────────────
module spokeVnet 'modules/spoke-vnet.bicep' = {
  name: 'spoke-vnet'
  scope: rg
  params: {
    location: location
    vnetName: 'vnet-spoke-${prefix}-001'
    addressPrefix: spokeAddressPrefix
    appNsgId: nsgs.outputs.appNsgId
    dataNsgId: nsgs.outputs.dataNsgId
    integrationNsgId: nsgs.outputs.integrationNsgId
    routeTableId: routeTable.outputs.routeTableId
    environment: environment
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// ─── VNet Peering: Spoke → Hub ────────────────────────────────────────────────
module peeringToHub 'modules/peering.bicep' = {
  name: 'peering-spoke-to-hub'
  scope: rg
  params: {
    localVnetName: spokeVnet.outputs.vnetName
    remoteVnetId: hubVnetId
    peeringName: 'peer-${prefix}-to-hub'
    useRemoteGateways: landingZoneType != 'sandbox'
    allowForwardedTraffic: true
  }
}

// ─── Outputs ──────────────────────────────────────────────────────────────────
output spokeVnetId string = spokeVnet.outputs.vnetId
output spokeVnetName string = spokeVnet.outputs.vnetName
output appSubnetId string = spokeVnet.outputs.appSubnetId
output dataSubnetId string = spokeVnet.outputs.dataSubnetId
output privateEndpointSubnetId string = spokeVnet.outputs.privateEndpointSubnetId
output resourceGroupName string = rg.name
