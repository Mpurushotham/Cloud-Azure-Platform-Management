targetScope = 'subscription'

param workloadName string
param notificationEmailAddress string
param budgetAmount int

resource sandboxBudget 'Microsoft.Consumption/budgets@2023-05-01' = {
  name: 'budget-sandbox-${workloadName}'
  properties: {
    category: 'Cost'
    amount: budgetAmount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: '2024-01-01'
      endDate: '2030-12-31'
    }
    notifications: {
      'threshold-50': {
        enabled: true
        operator: 'GreaterThan'
        threshold: 50
        contactEmails: [notificationEmailAddress]
        thresholdType: 'Actual'
      }
      'threshold-80': {
        enabled: true
        operator: 'GreaterThan'
        threshold: 80
        contactEmails: [notificationEmailAddress]
        thresholdType: 'Actual'
      }
      'forecast-100': {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        contactEmails: [notificationEmailAddress]
        thresholdType: 'Forecasted'
      }
    }
  }
}

output budgetId string = sandboxBudget.id
