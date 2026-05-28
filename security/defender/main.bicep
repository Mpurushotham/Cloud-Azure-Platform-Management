targetScope = 'subscription'

@description('Log Analytics workspace resource ID for Defender data export')
param logAnalyticsWorkspaceId string

@description('Security contact email address')
param securityContactEmail string = 'security-team@contoso.com'

@description('Security contact phone number')
param securityContactPhone string = '+1-555-0100'

// ─── Defender for Cloud Plans ─────────────────────────────────────────────────
// Enable all Defender plans for comprehensive workload protection

resource defenderServers 'Microsoft.Security/pricings@2023-01-01' = {
  name: 'VirtualMachines'
  properties: {
    pricingTier: 'Standard'
    subPlan: 'P2'
  }
}

resource defenderStorage 'Microsoft.Security/pricings@2023-01-01' = {
  name: 'StorageAccounts'
  properties: {
    pricingTier: 'Standard'
    subPlan: 'DefenderForStorageV2'
  }
}

resource defenderSql 'Microsoft.Security/pricings@2023-01-01' = {
  name: 'SqlServers'
  properties: {
    pricingTier: 'Standard'
  }
}

resource defenderSqlOnVms 'Microsoft.Security/pricings@2023-01-01' = {
  name: 'SqlServerVirtualMachines'
  properties: {
    pricingTier: 'Standard'
  }
}

resource defenderAppService 'Microsoft.Security/pricings@2023-01-01' = {
  name: 'AppServices'
  properties: {
    pricingTier: 'Standard'
  }
}

resource defenderContainers 'Microsoft.Security/pricings@2023-01-01' = {
  name: 'Containers'
  properties: {
    pricingTier: 'Standard'
  }
}

resource defenderKeyVault 'Microsoft.Security/pricings@2023-01-01' = {
  name: 'KeyVaults'
  properties: {
    pricingTier: 'Standard'
  }
}

resource defenderArm 'Microsoft.Security/pricings@2023-01-01' = {
  name: 'Arm'
  properties: {
    pricingTier: 'Standard'
    subPlan: 'PerSubscription'
  }
}

resource defenderDns 'Microsoft.Security/pricings@2023-01-01' = {
  name: 'Dns'
  properties: {
    pricingTier: 'Standard'
  }
}

resource defenderOpenSourceDatabases 'Microsoft.Security/pricings@2023-01-01' = {
  name: 'OpenSourceRelationalDatabases'
  properties: {
    pricingTier: 'Standard'
  }
}

resource defenderCosmos 'Microsoft.Security/pricings@2023-01-01' = {
  name: 'CosmosDbs'
  properties: {
    pricingTier: 'Standard'
  }
}

// ─── Auto-Provisioning Settings ───────────────────────────────────────────────
resource autoProvisioningMma 'Microsoft.Security/autoProvisioningSettings@2017-08-01-preview' = {
  name: 'mma'
  properties: {
    autoProvision: 'Off'
  }
}

resource autoProvisioningAma 'Microsoft.Security/autoProvisioningSettings@2017-08-01-preview' = {
  name: 'MicrosoftMonitoringAgent'
  properties: {
    autoProvision: 'On'
  }
}

// ─── Security Contact ─────────────────────────────────────────────────────────
resource securityContact 'Microsoft.Security/securityContacts@2020-01-01-preview' = {
  name: 'default'
  properties: {
    email: securityContactEmail
    phone: securityContactPhone
    alertNotifications: {
      state: 'On'
      minimalSeverity: 'High'
    }
    notificationsByRole: {
      state: 'On'
      roles: ['Owner', 'ServiceAdmin']
    }
  }
}

// ─── Workspace Settings (link to Log Analytics) ───────────────────────────────
resource workspaceSettings 'Microsoft.Security/workspaceSettings@2017-08-01-preview' = {
  name: 'default'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    scope: subscription().id
  }
}

// ─── Continuous Export to Log Analytics ──────────────────────────────────────
resource continuousExport 'Microsoft.Security/automations@2023-11-15' = {
  name: 'ExportToEventHub'
  location: 'eastus'
  properties: {
    description: 'Continuous export of Defender for Cloud alerts and recommendations to Log Analytics'
    isEnabled: true
    scopes: [
      {
        description: 'Subscription scope'
        scopePath: subscription().id
      }
    ]
    sources: [
      {
        eventSource: 'Alerts'
        ruleSets: [
          {
            rules: [
              {
                propertyJPath: 'Severity'
                propertyType: 'String'
                expectedValue: 'High'
                operator: 'Contains'
              }
            ]
          }
        ]
      }
      {
        eventSource: 'Assessments'
        ruleSets: []
      }
      {
        eventSource: 'SecureScores'
        ruleSets: []
      }
    ]
    actions: [
      {
        actionType: 'Workspace'
        workspaceResourceId: logAnalyticsWorkspaceId
      }
    ]
  }
}

output defenderServersId string = defenderServers.id
output continuousExportId string = continuousExport.id
