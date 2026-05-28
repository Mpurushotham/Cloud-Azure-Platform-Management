param location string
param vnetName string
param addressPrefix string
param ddosProtectionPlanId string
param environment string
param logAnalyticsWorkspaceId string

// ─── Network Security Groups ─────────────────────────────────────────────────
resource nsgManagement 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: 'nsg-management-${environment}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-Bastion-Inbound'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '10.0.2.0/26'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: ['22', '3389']
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
  tags: {
    Environment: environment
    ManagedBy: 'platform-team'
  }
}

// ─── Route Table: force tunnel all traffic through Azure Firewall ─────────────
resource routeTableManagement 'Microsoft.Network/routeTables@2023-06-01' = {
  name: 'rt-management-${environment}'
  location: location
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'default-to-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.0.4'
        }
      }
    ]
  }
}

// ─── Hub Virtual Network ─────────────────────────────────────────────────────
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-06-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [addressPrefix]
    }
    enableDdosProtection: true
    ddosProtectionPlan: {
      id: ddosProtectionPlanId
    }
    dhcpOptions: {
      dnsServers: ['10.0.0.4']
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.0.0.0/26'
        }
      }
      {
        name: 'AzureFirewallManagementSubnet'
        properties: {
          addressPrefix: '10.0.0.64/26'
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.0.1.0/27'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.2.0/26'
        }
      }
      {
        name: 'ManagementSubnet'
        properties: {
          addressPrefix: '10.0.3.0/24'
          networkSecurityGroup: { id: nsgManagement.id }
          routeTable: { id: routeTableManagement.id }
        }
      }
      {
        name: 'DNSResolverSubnet'
        properties: {
          addressPrefix: '10.0.4.0/28'
          delegations: [
            {
              name: 'dns-resolver-delegation'
              properties: {
                serviceName: 'Microsoft.Network/dnsResolvers'
              }
            }
          ]
        }
      }
    ]
  }
  tags: {
    Environment: environment
    ManagedBy: 'platform-team'
    Application: 'hub-connectivity'
    CostCenter: 'CC-PLATFORM'
    Owner: 'platform-team@contoso.com'
  }
}

// ─── Diagnostic Settings ─────────────────────────────────────────────────────
resource vnetDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${vnetName}'
  scope: hubVnet
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: { enabled: true, days: 90 }
      }
    ]
  }
}

// ─── Outputs ─────────────────────────────────────────────────────────────────
output vnetId string = hubVnet.id
output vnetName string = hubVnet.name
output firewallSubnetId string = '${hubVnet.id}/subnets/AzureFirewallSubnet'
output firewallMgmtSubnetId string = '${hubVnet.id}/subnets/AzureFirewallManagementSubnet'
output gatewaySubnetId string = '${hubVnet.id}/subnets/GatewaySubnet'
output bastionSubnetId string = '${hubVnet.id}/subnets/AzureBastionSubnet'
output managementSubnetId string = '${hubVnet.id}/subnets/ManagementSubnet'
output dnsResolverSubnetId string = '${hubVnet.id}/subnets/DNSResolverSubnet'
