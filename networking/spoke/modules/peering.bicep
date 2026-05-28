param localVnetName string
param remoteVnetId string
param peeringName string
param useRemoteGateways bool
param allowForwardedTraffic bool

resource localVnet 'Microsoft.Network/virtualNetworks@2023-06-01' existing = {
  name: localVnetName
}

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-06-01' = {
  parent: localVnet
  name: peeringName
  properties: {
    remoteVirtualNetwork: { id: remoteVnetId }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: false
    useRemoteGateways: useRemoteGateways
  }
}

output peeringId string = peering.id
