targetScope = 'resourceGroup'

@description('Location for NSG resources')
param location string = 'eastus'

@description('Environment')
param environment string

@description('Log Analytics workspace resource ID for NSG flow logs')
param logAnalyticsWorkspaceId string

@description('Storage account resource ID for NSG flow log raw storage')
param storageAccountId string

// ─── Hub Management NSG ───────────────────────────────────────────────────────
resource nsgHubManagement 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: 'nsg-hub-management-${environment}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-Bastion-SSH-RDP'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'AzureBastionSubnet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: ['22', '3389']
        }
      }
      {
        name: 'Allow-AzureMonitor-Outbound'
        properties: {
          priority: 200
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'AzureMonitor'
          destinationPortRange: '443'
        }
      }
      {
        name: 'Deny-Internet-Inbound'
        properties: {
          priority: 4000
          protocol: '*'
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
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
  tags: {
    Environment: environment
    ManagedBy: 'platform-team'
  }
}

// ─── NSG Flow Logs ────────────────────────────────────────────────────────────
resource nsgFlowLog 'Microsoft.Network/networkWatchers/flowLogs@2023-06-01' = {
  name: 'networkWatcher_${location}/flowlog-hub-management-${environment}'
  location: location
  properties: {
    storageId: storageAccountId
    enabled: true
    retentionPolicy: {
      days: 90
      enabled: true
    }
    format: {
      type: 'JSON'
      version: 2
    }
    flowAnalyticsConfiguration: {
      networkWatcherFlowAnalyticsConfiguration: {
        enabled: true
        workspaceId: logAnalyticsWorkspaceId
        workspaceRegion: location
        trafficAnalyticsInterval: 10
      }
    }
  }
}

output nsgHubManagementId string = nsgHubManagement.id
