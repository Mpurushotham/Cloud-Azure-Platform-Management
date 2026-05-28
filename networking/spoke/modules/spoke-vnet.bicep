param location string
param vnetName string
param addressPrefix string
param appNsgId string
param dataNsgId string
param integrationNsgId string
param routeTableId string
param environment string
param logAnalyticsWorkspaceId string

var octets = split(addressPrefix, '.')
var base = '${octets[0]}.${octets[1]}'

resource spokeVnet 'Microsoft.Network/virtualNetworks@2023-06-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [addressPrefix]
    }
    dhcpOptions: {
      dnsServers: ['10.0.0.4']
    }
    subnets: [
      {
        name: 'AppSubnet'
        properties: {
          addressPrefix: '${base}.1.0/24'
          networkSecurityGroup: { id: appNsgId }
          routeTable: { id: routeTableId }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'DataSubnet'
        properties: {
          addressPrefix: '${base}.2.0/24'
          networkSecurityGroup: { id: dataNsgId }
          routeTable: { id: routeTableId }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'IntegrationSubnet'
        properties: {
          addressPrefix: '${base}.3.0/24'
          networkSecurityGroup: { id: integrationNsgId }
          routeTable: { id: routeTableId }
          delegations: [
            {
              name: 'apim-delegation'
              properties: { serviceName: 'Microsoft.Web/serverFarms' }
            }
          ]
        }
      }
      {
        name: 'PrivateEndpointSubnet'
        properties: {
          addressPrefix: '${base}.4.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
  tags: {
    Environment: environment
    ManagedBy: 'platform-team'
  }
}

resource vnetDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${vnetName}'
  scope: spokeVnet
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}

output vnetId string = spokeVnet.id
output vnetName string = spokeVnet.name
output appSubnetId string = '${spokeVnet.id}/subnets/AppSubnet'
output dataSubnetId string = '${spokeVnet.id}/subnets/DataSubnet'
output integrationSubnetId string = '${spokeVnet.id}/subnets/IntegrationSubnet'
output privateEndpointSubnetId string = '${spokeVnet.id}/subnets/PrivateEndpointSubnet'
