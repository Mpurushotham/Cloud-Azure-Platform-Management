targetScope = 'subscription'

@description('Azure region')
param location string = 'eastus'

@description('Workload/team name for this sandbox')
param workloadName string

@description('Sandbox owner email — receives budget alerts and auto-shutdown notices')
param ownerEmail string

@description('Log Analytics workspace resource ID')
param logAnalyticsWorkspaceId string

@description('Monthly budget limit in USD (default $200)')
param monthlyBudgetUsd int = 200

var environment = 'sandbox'
var prefix = '${workloadName}-${environment}'
var rgName = 'rg-sandbox-${prefix}-${location}-001'

// ─── Resource Group ───────────────────────────────────────────────────────────
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: rgName
  location: location
  tags: {
    Environment: environment
    ManagedBy: 'platform-team'
    Application: workloadName
    CostCenter: 'CC-SANDBOX'
    Owner: ownerEmail
    AutoExpiry: dateTimeAdd(utcNow(), 'P90D')
  }
}

// ─── Isolated Sandbox VNet (no hub peering) ───────────────────────────────────
module sandboxVnet 'modules/sandbox-vnet.bicep' = {
  name: 'sandbox-vnet'
  scope: rg
  params: {
    location: location
    vnetName: 'vnet-sandbox-${prefix}-001'
    addressPrefix: '172.16.0.0/16'
    environment: environment
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// ─── Auto-shutdown Schedule (Azure Automation / Scheduled Action) ─────────────
module autoShutdown 'modules/auto-shutdown.bicep' = {
  name: 'sandbox-auto-shutdown'
  scope: rg
  params: {
    location: location
    environment: environment
    ownerEmail: ownerEmail
  }
}

// ─── Budget with strict $200 cap ─────────────────────────────────────────────
module sandboxBudget 'modules/sandbox-budget.bicep' = {
  name: 'sandbox-budget'
  params: {
    workloadName: workloadName
    notificationEmailAddress: ownerEmail
    budgetAmount: monthlyBudgetUsd
  }
}

// ─── Outputs ─────────────────────────────────────────────────────────────────
output sandboxVnetId string = sandboxVnet.outputs.vnetId
output resourceGroupName string = rg.name
