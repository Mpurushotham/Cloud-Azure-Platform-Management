param location string
param firewallName string
param firewallSubnetId string
param firewallMgmtSubnetId string
param environment string
param logAnalyticsWorkspaceId string

// ─── Public IPs ──────────────────────────────────────────────────────────────
resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: 'pip-${firewallName}'
  location: location
  sku: { name: 'Standard', tier: 'Regional' }
  zones: ['1', '2', '3']
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  tags: {
    Environment: environment
    ManagedBy: 'platform-team'
  }
}

resource firewallMgmtPublicIp 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: 'pip-mgmt-${firewallName}'
  location: location
  sku: { name: 'Standard', tier: 'Regional' }
  zones: ['1', '2', '3']
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  tags: {
    Environment: environment
    ManagedBy: 'platform-team'
  }
}

// ─── Firewall Policy (Premium) ───────────────────────────────────────────────
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-06-01' = {
  name: 'fwpol-${firewallName}'
  location: location
  properties: {
    sku: { tier: 'Premium' }
    threatIntelMode: 'Deny'
    threatIntelWhitelist: {
      fqdns: []
      ipAddresses: []
    }
    intrusionDetection: {
      mode: 'Deny'
      configuration: {
        signatureOverrides: []
        bypassTrafficSettings: []
      }
    }
    transportSecurity: {
      certificateAuthority: {}
    }
    dnsSettings: {
      servers: []
      enableProxy: true
    }
  }
  tags: {
    Environment: environment
    ManagedBy: 'platform-team'
  }
}

// ─── Application Rule Collection ─────────────────────────────────────────────
resource appRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-06-01' = {
  parent: firewallPolicy
  name: 'DefaultApplicationRuleCollectionGroup'
  properties: {
    priority: 300
    ruleCollections: [
      {
        name: 'AllowAzureServices'
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        priority: 100
        action: { type: 'Allow' }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'AllowWindowsUpdate'
            protocols: [
              { protocolType: 'Https', port: 443 }
            ]
            targetFqdns: ['*.update.microsoft.com', '*.windowsupdate.com', '*.microsoft.com']
            sourceAddresses: ['10.0.0.0/8']
            terminateTLS: false
          }
          {
            ruleType: 'ApplicationRule'
            name: 'AllowAzureMonitor'
            protocols: [
              { protocolType: 'Https', port: 443 }
            ]
            targetFqdns: ['*.oms.opinsights.azure.com', '*.azure-automation.net', '*.monitor.azure.com']
            sourceAddresses: ['10.0.0.0/8']
            terminateTLS: false
          }
        ]
      }
    ]
  }
}

// ─── Network Rule Collection ──────────────────────────────────────────────────
resource networkRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-06-01' = {
  parent: firewallPolicy
  name: 'DefaultNetworkRuleCollectionGroup'
  properties: {
    priority: 200
    ruleCollections: [
      {
        name: 'AllowAzureDNS'
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        priority: 100
        action: { type: 'Allow' }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'AllowDNS'
            ipProtocols: ['UDP', 'TCP']
            sourceAddresses: ['10.0.0.0/8']
            destinationAddresses: ['168.63.129.16']
            destinationPorts: ['53']
          }
        ]
      }
      {
        name: 'AllowOnPremToAzure'
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        priority: 200
        action: { type: 'Allow' }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'AllowOnPremRFC1918'
            ipProtocols: ['Any']
            sourceAddresses: ['192.168.0.0/16']
            destinationAddresses: ['10.0.0.0/8']
            destinationPorts: ['*']
          }
        ]
      }
    ]
  }
  dependsOn: [appRuleCollectionGroup]
}

// ─── Azure Firewall Premium ───────────────────────────────────────────────────
resource azureFirewall 'Microsoft.Network/azureFirewalls@2023-06-01' = {
  name: firewallName
  location: location
  zones: ['1', '2', '3']
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Premium'
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: firewallSubnetId }
          publicIPAddress: { id: firewallPublicIp.id }
        }
      }
    ]
    managementIpConfiguration: {
      name: 'mgmtIpConfig'
      properties: {
        subnet: { id: firewallMgmtSubnetId }
        publicIPAddress: { id: firewallMgmtPublicIp.id }
      }
    }
    firewallPolicy: { id: firewallPolicy.id }
    threatIntelMode: 'Deny'
  }
  tags: {
    Environment: environment
    ManagedBy: 'platform-team'
    Application: 'hub-connectivity'
    CostCenter: 'CC-PLATFORM'
    Owner: 'platform-team@contoso.com'
  }
  dependsOn: [networkRuleCollectionGroup]
}

// ─── Diagnostic Settings ─────────────────────────────────────────────────────
resource firewallDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${firewallName}'
  scope: azureFirewall
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { category: 'AzureFirewallApplicationRule', enabled: true }
      { category: 'AzureFirewallNetworkRule', enabled: true }
      { category: 'AzureFirewallDnsProxy', enabled: true }
      { category: 'AzureFirewallThreatIntelLog', enabled: true }
      { category: 'AzureFirewallIDPSSignature', enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}

// ─── Outputs ─────────────────────────────────────────────────────────────────
output firewallId string = azureFirewall.id
output firewallPrivateIp string = azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallPublicIp string = firewallPublicIp.properties.ipAddress
output firewallPolicyId string = firewallPolicy.id
