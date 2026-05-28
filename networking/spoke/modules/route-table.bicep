param location string
param prefix string
param firewallPrivateIp string
param environment string

resource routeTable 'Microsoft.Network/routeTables@2023-06-01' = {
  name: 'rt-spoke-${prefix}'
  location: location
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'default-to-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
      {
        name: 'rfc1918-10-to-firewall'
        properties: {
          addressPrefix: '10.0.0.0/8'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
      {
        name: 'rfc1918-172-to-firewall'
        properties: {
          addressPrefix: '172.16.0.0/12'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
      {
        name: 'rfc1918-192-to-firewall'
        properties: {
          addressPrefix: '192.168.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
    ]
  }
  tags: { Environment: environment, ManagedBy: 'platform-team' }
}

output routeTableId string = routeTable.id
