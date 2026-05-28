targetScope = 'subscription'

@description('Azure region for all hub resources')
param location string = 'eastus'

@description('Environment name')
@allowed(['prod', 'staging', 'dev'])
param environment string = 'prod'

@description('Hub VNet address space')
param hubVnetAddressPrefix string = '10.0.0.0/16'

@description('On-premises address prefix for VPN connectivity')
param onPremAddressPrefix string = '192.168.0.0/16'

@description('VPN shared key (should come from Key Vault reference in production)')
@secure()
param vpnSharedKey string

@description('Log Analytics workspace resource ID')
param logAnalyticsWorkspaceId string

var prefix = 'hub-conn-${environment}'
var rgName = 'rg-${prefix}-${location}-001'

// ─── Resource Group ──────────────────────────────────────────────────────────
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: rgName
  location: location
  tags: {
    Environment: environment
    ManagedBy: 'platform-team'
    Application: 'hub-connectivity'
    CostCenter: 'CC-PLATFORM'
    Owner: 'platform-team@contoso.com'
  }
}

// ─── DDoS Protection Plan ────────────────────────────────────────────────────
module ddosProtection 'modules/ddos.bicep' = {
  name: 'ddos-protection'
  scope: rg
  params: {
    location: location
    ddosPlanName: 'ddos-${prefix}-001'
    environment: environment
  }
}

// ─── Hub Virtual Network ─────────────────────────────────────────────────────
module hubVnet 'modules/vnet.bicep' = {
  name: 'hub-vnet'
  scope: rg
  params: {
    location: location
    vnetName: 'vnet-${prefix}-001'
    addressPrefix: hubVnetAddressPrefix
    ddosProtectionPlanId: ddosProtection.outputs.ddosPlanId
    environment: environment
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// ─── Azure Firewall Premium ──────────────────────────────────────────────────
module firewall 'modules/firewall.bicep' = {
  name: 'azure-firewall'
  scope: rg
  params: {
    location: location
    firewallName: 'fw-${prefix}-001'
    firewallSubnetId: hubVnet.outputs.firewallSubnetId
    firewallMgmtSubnetId: hubVnet.outputs.firewallMgmtSubnetId
    environment: environment
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// ─── VPN Gateway ─────────────────────────────────────────────────────────────
module vpnGateway 'modules/vpn-gateway.bicep' = {
  name: 'vpn-gateway'
  scope: rg
  params: {
    location: location
    gatewayName: 'vpng-${prefix}-001'
    gatewaySubnetId: hubVnet.outputs.gatewaySubnetId
    onPremAddressPrefix: onPremAddressPrefix
    sharedKey: vpnSharedKey
    environment: environment
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// ─── Azure Bastion ───────────────────────────────────────────────────────────
module bastion 'modules/bastion.bicep' = {
  name: 'azure-bastion'
  scope: rg
  params: {
    location: location
    bastionName: 'bas-${prefix}-001'
    bastionSubnetId: hubVnet.outputs.bastionSubnetId
    environment: environment
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// ─── Outputs ─────────────────────────────────────────────────────────────────
output hubVnetId string = hubVnet.outputs.vnetId
output hubVnetName string = hubVnet.outputs.vnetName
output firewallPrivateIp string = firewall.outputs.firewallPrivateIp
output firewallPublicIp string = firewall.outputs.firewallPublicIp
output bastionPublicIp string = bastion.outputs.bastionPublicIp
output ddosPlanId string = ddosProtection.outputs.ddosPlanId
output resourceGroupName string = rg.name
