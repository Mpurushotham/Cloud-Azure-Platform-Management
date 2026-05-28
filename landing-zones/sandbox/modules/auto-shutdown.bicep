param location string
param environment string
param ownerEmail string

// Automation Account for scheduled runbook-based auto-shutdown
resource automationAccount 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: 'aa-sandbox-autoshutdown-${environment}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: { name: 'Basic' }
    publicNetworkAccess: false
    disableLocalAuth: true
  }
  tags: { Environment: environment, ManagedBy: 'platform-team' }
}

// Runbook: Stop all VMs tagged AutoShutdown:true at 6PM UTC daily
resource shutdownRunbook 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = {
  parent: automationAccount
  name: 'Stop-SandboxVMs'
  properties: {
    runbookType: 'PowerShell'
    logProgress: true
    logVerbose: false
    description: 'Stops all VMs with tag AutoShutdown=true in sandbox resource groups'
    publishContentLink: {
      uri: 'https://raw.githubusercontent.com/contoso/cloud-azure-platform/main/automation/runbooks/Start-StopVMs.ps1'
      version: '1.0.0.0'
    }
  }
}

// Schedule: Daily 6PM UTC
resource shutdownSchedule 'Microsoft.Automation/automationAccounts/schedules@2023-11-01' = {
  parent: automationAccount
  name: 'daily-shutdown-1800'
  properties: {
    description: 'Daily sandbox VM auto-shutdown at 18:00 UTC'
    startTime: '2024-01-01T18:00:00+00:00'
    expiryTime: '9999-12-31T00:00:00+00:00'
    interval: 1
    frequency: 'Day'
    timeZone: 'UTC'
  }
}

output automationAccountId string = automationAccount.id
output automationAccountPrincipalId string = automationAccount.identity.principalId
