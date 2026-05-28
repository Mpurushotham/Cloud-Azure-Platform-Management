targetScope = 'subscription'

@description('Environment — determines budget amount')
@allowed(['prod', 'staging', 'dev', 'sandbox'])
param environment string

@description('Workload name for naming')
param workloadName string = 'platform'

@description('Notification email address for budget alerts')
param notificationEmailAddress string

@description('Override budget amount (0 = use environment default)')
param budgetAmountOverride int = 0

// ─── Budget amounts per environment ──────────────────────────────────────────
var budgetAmounts = {
  prod: 10000
  staging: 2000
  dev: 500
  sandbox: 200
}

var budgetAmount = budgetAmountOverride > 0 ? budgetAmountOverride : budgetAmounts[environment]

// ─── Monthly subscription budget ─────────────────────────────────────────────
resource subscriptionBudget 'Microsoft.Consumption/budgets@2023-05-01' = {
  name: 'budget-${workloadName}-${environment}-monthly'
  properties: {
    category: 'Cost'
    amount: budgetAmount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: '2024-01-01'
      endDate: '2030-12-31'
    }
    filter: {}
    notifications: {
      'threshold-50-actual': {
        enabled: true
        operator: 'GreaterThan'
        threshold: 50
        contactEmails: [notificationEmailAddress]
        contactRoles: ['Owner', 'Contributor']
        thresholdType: 'Actual'
      }
      'threshold-75-actual': {
        enabled: true
        operator: 'GreaterThan'
        threshold: 75
        contactEmails: [notificationEmailAddress]
        contactRoles: ['Owner', 'Contributor']
        thresholdType: 'Actual'
      }
      'threshold-90-actual': {
        enabled: true
        operator: 'GreaterThan'
        threshold: 90
        contactEmails: [notificationEmailAddress]
        contactRoles: ['Owner', 'Contributor']
        thresholdType: 'Actual'
      }
      'threshold-100-actual': {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        contactEmails: [notificationEmailAddress]
        contactRoles: ['Owner', 'Contributor']
        thresholdType: 'Actual'
      }
      'threshold-100-forecast': {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        contactEmails: [notificationEmailAddress]
        contactRoles: ['Owner']
        thresholdType: 'Forecasted'
      }
    }
  }
}

output budgetId string = subscriptionBudget.id
output budgetAmount int = budgetAmount
