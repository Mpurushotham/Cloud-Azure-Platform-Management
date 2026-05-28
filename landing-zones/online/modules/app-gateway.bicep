param location string
param appGwName string
param environment string
param appSubnetId string
param logAnalyticsWorkspaceId string

resource appGwPublicIp 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: 'pip-${appGwName}'
  location: location
  sku: { name: 'Standard', tier: 'Regional' }
  zones: ['1', '2', '3']
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: appGwName
    }
  }
  tags: { Environment: environment, ManagedBy: 'platform-team' }
}

resource appGateway 'Microsoft.Network/applicationGateways@2023-06-01' = {
  name: appGwName
  location: location
  zones: ['1', '2', '3']
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: 2
    }
    autoscaleConfiguration: {
      minCapacity: 2
      maxCapacity: 10
    }
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Detection'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
    enableHttp2: true
    gatewayIPConfigurations: [
      {
        name: 'gwIpConfig'
        properties: {
          subnet: { id: appSubnetId }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'frontendPublicIp'
        properties: {
          publicIPAddress: { id: appGwPublicIp.id }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port443'
        properties: { port: 443 }
      }
      {
        name: 'port80'
        properties: { port: 80 }
      }
    ]
    backendAddressPools: [
      {
        name: 'defaultBackendPool'
        properties: { backendAddresses: [] }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'defaultHttpSettings'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 30
        }
      }
    ]
    httpListeners: [
      {
        name: 'httpsListener'
        properties: {
          frontendIPConfiguration: { id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGwName, 'frontendPublicIp') }
          frontendPort: { id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGwName, 'port443') }
          protocol: 'Https'
          requireServerNameIndication: false
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'defaultRule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: { id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGwName, 'httpsListener') }
          backendAddressPool: { id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGwName, 'defaultBackendPool') }
          backendHttpSettings: { id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGwName, 'defaultHttpSettings') }
        }
      }
    ]
  }
  tags: {
    Environment: environment
    ManagedBy: 'platform-team'
    Application: 'online-ingress'
    CostCenter: 'CC-WORKLOAD'
    Owner: 'platform-team@contoso.com'
  }
}

resource appGwDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${appGwName}'
  scope: appGateway
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { category: 'ApplicationGatewayAccessLog', enabled: true }
      { category: 'ApplicationGatewayPerformanceLog', enabled: true }
      { category: 'ApplicationGatewayFirewallLog', enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}

output appGwId string = appGateway.id
output appGwPublicIp string = appGwPublicIp.properties.ipAddress
