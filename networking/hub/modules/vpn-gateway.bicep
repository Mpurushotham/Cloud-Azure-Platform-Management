param location string
param gatewayName string
param gatewaySubnetId string
param onPremAddressPrefix string
@secure()
param sharedKey string
param environment string
param logAnalyticsWorkspaceId string

// ─── Public IPs (active-active requires 2) ────────────────────────────────────
resource pipGateway1 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: 'pip-${gatewayName}-1'
  location: location
  sku: { name: 'Standard', tier: 'Regional' }
  zones: ['1', '2', '3']
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  tags: { Environment: environment, ManagedBy: 'platform-team' }
}

resource pipGateway2 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: 'pip-${gatewayName}-2'
  location: location
  sku: { name: 'Standard', tier: 'Regional' }
  zones: ['1', '2', '3']
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  tags: { Environment: environment, ManagedBy: 'platform-team' }
}

// ─── VPN Gateway (active-active, zone-redundant) ──────────────────────────────
resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2023-06-01' = {
  name: gatewayName
  location: location
  properties: {
    sku: {
      name: 'VpnGw2AZ'
      tier: 'VpnGw2AZ'
    }
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: true
    activeActive: true
    bgpSettings: {
      asn: 65515
    }
    ipConfigurations: [
      {
        name: 'gwIpConfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: { id: gatewaySubnetId }
          publicIPAddress: { id: pipGateway1.id }
        }
      }
      {
        name: 'gwIpConfig2'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: { id: gatewaySubnetId }
          publicIPAddress: { id: pipGateway2.id }
        }
      }
    ]
    vpnClientConfiguration: {
      vpnClientProtocols: ['IkeV2']
    }
  }
  tags: {
    Environment: environment
    ManagedBy: 'platform-team'
    Application: 'hub-connectivity'
    CostCenter: 'CC-PLATFORM'
    Owner: 'platform-team@contoso.com'
  }
}

// ─── Local Network Gateway (on-premises) ─────────────────────────────────────
resource localNetworkGateway 'Microsoft.Network/localNetworkGateways@2023-06-01' = {
  name: 'lng-onprem-${environment}'
  location: location
  properties: {
    localNetworkAddressSpace: {
      addressPrefixes: [onPremAddressPrefix]
    }
    gatewayIpAddress: '203.0.113.1'
    bgpSettings: {
      asn: 65000
      bgpPeeringAddress: '192.168.255.254'
    }
  }
  tags: { Environment: environment, ManagedBy: 'platform-team' }
}

// ─── VPN Connection ───────────────────────────────────────────────────────────
resource vpnConnection 'Microsoft.Network/connections@2023-06-01' = {
  name: 'vpnconn-onprem-${environment}'
  location: location
  properties: {
    connectionType: 'IPsec'
    virtualNetworkGateway1: { id: vpnGateway.id, properties: {} }
    localNetworkGateway2: { id: localNetworkGateway.id, properties: {} }
    sharedKey: sharedKey
    enableBgp: true
    ipsecPolicies: [
      {
        ikeEncryption: 'AES256'
        ikeIntegrity: 'SHA256'
        dhGroup: 'DHGroup14'
        ipsecEncryption: 'AES256'
        ipsecIntegrity: 'SHA256'
        pfsGroup: 'PFS14'
        saLifeTimeSeconds: 27000
        saDataSizeKilobytes: 102400000
      }
    ]
  }
  tags: { Environment: environment, ManagedBy: 'platform-team' }
}

// ─── Diagnostic Settings ─────────────────────────────────────────────────────
resource gatewayDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${gatewayName}'
  scope: vpnGateway
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { category: 'GatewayDiagnosticLog', enabled: true }
      { category: 'TunnelDiagnosticLog', enabled: true }
      { category: 'RouteDiagnosticLog', enabled: true }
      { category: 'IKEDiagnosticLog', enabled: true }
      { category: 'P2SDiagnosticLog', enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}

output gatewayId string = vpnGateway.id
output gatewayPublicIp1 string = pipGateway1.properties.ipAddress
output gatewayPublicIp2 string = pipGateway2.properties.ipAddress
