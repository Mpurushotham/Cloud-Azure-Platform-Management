param location string
param environment string
param prefix string
param landingZoneType string

resource appNsg 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: 'nsg-app-${prefix}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-LB-Inbound'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: landingZoneType == 'online' ? 'Allow-AppGW-Inbound' : 'Allow-Internal-Inbound'
        properties: {
          priority: 200
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: landingZoneType == 'online' ? 'GatewayManager' : '10.0.0.0/8'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: ['80', '443', '8080', '8443']
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

resource dataNsg 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: 'nsg-data-${prefix}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-App-To-Data'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefixes: ['10.0.1.0/24']
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: ['1433', '5432', '3306', '6379']
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

resource integrationNsg 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: 'nsg-integration-${prefix}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-APIM-Inbound'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'ApiManagement'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3443'
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

output appNsgId string = appNsg.id
output dataNsgId string = dataNsg.id
output integrationNsgId string = integrationNsg.id
