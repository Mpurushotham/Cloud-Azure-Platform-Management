targetScope = 'resourceGroup'

@description('Azure region')
param location string = 'eastus'

@description('Log Analytics workspace resource ID')
param logAnalyticsWorkspaceId string

@description('Environment')
param environment string = 'prod'

@description('Notification email addresses')
param alertEmailAddresses array = ['finops@contoso.com', 'platform-team@contoso.com']

// ─── Action Group for Cost Alerts ────────────────────────────────────────────
resource costActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-cost-${environment}'
  location: 'global'
  properties: {
    enabled: true
    groupShortName: 'CostAlert'
    emailReceivers: [for email in alertEmailAddresses: {
      name: 'email-cost-${uniqueString(email)}'
      emailAddress: email
      useCommonAlertSchema: true
    }]
  }
  tags: { Environment: environment, ManagedBy: 'platform-team' }
}

// ─── Cost Anomaly Alert ───────────────────────────────────────────────────────
resource costAnomalyAlert 'Microsoft.CostManagement/scheduledActions@2023-04-01-preview' = {
  name: 'anomaly-detection-${environment}'
  kind: 'InsightAlert'
  properties: {
    displayName: 'Cost Anomaly Detection — ${toUpper(environment)}'
    status: 'Enabled'
    notification: {
      to: alertEmailAddresses
      subject: '[Azure Cost Alert] Cost anomaly detected in ${environment} environment'
      message: 'Azure Cost Management has detected an unusual cost pattern. Please review your spending at https://portal.azure.com/#blade/Microsoft_Azure_CostManagement/Menu/overview'
    }
    schedule: {
      frequency: 'Daily'
      startDate: '2024-01-01T08:00:00Z'
      endDate: '2030-12-31T00:00:00Z'
    }
  }
}

// ─── Advisor Cost Recommendation Alert ───────────────────────────────────────
resource advisorCostAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'alert-advisor-cost-recommendations-${environment}'
  location: location
  properties: {
    displayName: 'FinOps: New Advisor Cost Recommendations Available'
    description: 'Alerts when Azure Advisor identifies new cost optimization opportunities (rightsizing, reserved instances, idle resources)'
    severity: 2
    enabled: true
    evaluationFrequency: 'P1D'
    windowSize: 'P1D'
    scopes: [logAnalyticsWorkspaceId]
    criteria: {
      allOf: [
        {
          query: '''
            AzureActivity
            | where OperationNameValue == "Microsoft.Advisor/recommendations/write"
            | where ActivityStatusValue == "Succeeded"
            | extend Category = tostring(parse_json(Properties).category)
            | where Category == "Cost"
            | project TimeGenerated, ResourceId, Caller
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [costActionGroup.id]
      customProperties: {}
    }
  }
}

output costActionGroupId string = costActionGroup.id
