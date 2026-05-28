param location string
param vnetName string
param addressPrefix string
param environment string
param logAnalyticsWorkspaceId string

resource nsgSandbox 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: 'nsg-${vnetName}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-Internal'
        properties: {
          priority: 100
          protocol: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '172.16.0.0/16'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority: 4096
          protocol: '*'
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
  tags: { Environment: environment, ManagedBy: 'platform-team' }
}

resource sandboxVnet 'Microsoft.Network/virtualNetworks@2023-06-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [addressPrefix]
    }
    subnets: [
      {
        name: 'DefaultSubnet'
        properties: {
          addressPrefix: '172.16.0.0/24'
          networkSecurityGroup: { id: nsgSandbox.id }
        }
      }
    ]
  }
  tags: {
    Environment: environment
    ManagedBy: 'platform-team'
  }
}

output vnetId string = sandboxVnet.id
output defaultSubnetId string = '${sandboxVnet.id}/subnets/DefaultSubnet'
