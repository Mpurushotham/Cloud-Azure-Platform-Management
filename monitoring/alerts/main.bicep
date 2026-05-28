targetScope = 'resourceGroup'

@description('Azure region')
param location string = 'eastus'

@description('Log Analytics workspace resource ID')
param logAnalyticsWorkspaceId string

@description('Environment')
param environment string = 'prod'

@description('Alert notification email addresses')
param alertEmailAddresses array = ['platform-team@contoso.com']

@description('Teams webhook URL for critical alerts')
@secure()
param teamsWebhookUrl string = ''

// ─── Action Group ─────────────────────────────────────────────────────────────
resource actionGroupCritical 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-critical-${environment}'
  location: 'global'
  properties: {
    enabled: true
    groupShortName: 'CritAlert'
    emailReceivers: [for email in alertEmailAddresses: {
      name: 'email-${uniqueString(email)}'
      emailAddress: email
      useCommonAlertSchema: true
    }]
    webhookReceivers: !empty(teamsWebhookUrl) ? [
      {
        name: 'teams-webhook'
        serviceUri: teamsWebhookUrl
        useCommonAlertSchema: true
        useAadAuth: false
        objectId: ''
        identifierUri: ''
        tenantId: ''
      }
    ] : []
  }
  tags: { Environment: environment, ManagedBy: 'platform-team' }
}

resource actionGroupWarning 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-warning-${environment}'
  location: 'global'
  properties: {
    enabled: true
    groupShortName: 'WarnAlert'
    emailReceivers: [for email in alertEmailAddresses: {
      name: 'email-warn-${uniqueString(email)}'
      emailAddress: email
      useCommonAlertSchema: true
    }]
    webhookReceivers: []
  }
  tags: { Environment: environment, ManagedBy: 'platform-team' }
}

// ─── VM CPU Alert ─────────────────────────────────────────────────────────────
resource alertVmCpu 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'alert-vm-cpu-high-${environment}'
  location: location
  properties: {
    displayName: 'VM CPU > 90% for 5 minutes'
    description: 'Alert when any VM CPU exceeds 90% for a sustained 5-minute period'
    severity: 0
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    scopes: [logAnalyticsWorkspaceId]
    criteria: {
      allOf: [
        {
          query: '''
            Perf
            | where ObjectName == "Processor" and CounterName == "% Processor Time" and InstanceName == "_Total"
            | where CounterValue > 90
            | summarize MaxCPU = max(CounterValue) by Computer, bin(TimeGenerated, 5m)
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
      actionGroups: [actionGroupCritical.id]
      customProperties: {}
    }
  }
}

// ─── VM Memory Alert ──────────────────────────────────────────────────────────
resource alertVmMemory 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'alert-vm-memory-high-${environment}'
  location: location
  properties: {
    displayName: 'VM Available Memory < 15%'
    description: 'Alert when VM available memory falls below 15% of total'
    severity: 1
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    scopes: [logAnalyticsWorkspaceId]
    criteria: {
      allOf: [
        {
          query: '''
            Perf
            | where ObjectName == "Memory" and CounterName == "% Available Memory"
            | where CounterValue < 15
            | summarize MinMemory = min(CounterValue) by Computer, bin(TimeGenerated, 5m)
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 3
            minFailingPeriodsToAlert: 2
          }
        }
      ]
    }
    actions: {
      actionGroups: [actionGroupWarning.id]
      customProperties: {}
    }
  }
}

// ─── Failed Sign-in Security Alert ───────────────────────────────────────────
resource alertFailedSignins 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'alert-security-failed-signins-${environment}'
  location: location
  properties: {
    displayName: 'Security: >10 Failed Sign-ins in 5 minutes'
    description: 'Critical security alert when more than 10 failed sign-in attempts detected in 5 minutes (potential brute force)'
    severity: 0
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    scopes: [logAnalyticsWorkspaceId]
    criteria: {
      allOf: [
        {
          query: '''
            SigninLogs
            | where ResultType != "0"
            | summarize FailedCount = count() by UserPrincipalName, bin(TimeGenerated, 5m)
            | where FailedCount > 10
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
      actionGroups: [actionGroupCritical.id]
      customProperties: { AlertType: 'Security' }
    }
  }
}

// ─── Azure Firewall Threat Intel Alert ───────────────────────────────────────
resource alertFirewallThreatIntel 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'alert-firewall-threat-intel-${environment}'
  location: location
  properties: {
    displayName: 'Security: Azure Firewall Threat Intelligence Hit'
    description: 'Critical security alert when Azure Firewall blocks traffic based on threat intelligence feed'
    severity: 0
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    scopes: [logAnalyticsWorkspaceId]
    criteria: {
      allOf: [
        {
          query: '''
            AzureDiagnostics
            | where Category == "AzureFirewallThreatIntelLog"
            | where msg_s contains "Deny"
            | project TimeGenerated, SourceIP = extract(@"from (\d+\.\d+\.\d+\.\d+)", 1, msg_s), DestIP = extract(@"to (\d+\.\d+\.\d+\.\d+)", 1, msg_s), msg_s
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
      actionGroups: [actionGroupCritical.id]
      customProperties: { AlertType: 'Security' }
    }
  }
}

// ─── Service Health Alert ─────────────────────────────────────────────────────
resource serviceHealthAlert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: 'alert-service-health-${environment}'
  location: 'global'
  properties: {
    enabled: true
    scopes: [subscription().id]
    description: 'Alert on Azure Service Health events (outages, planned maintenance, health advisories)'
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'ServiceHealth'
        }
        {
          field: 'properties.incidentType'
          containsAny: ['Incident', 'Maintenance', 'Informational', 'ActionRequired', 'Security']
        }
      ]
    }
    actions: {
      actionGroups: [
        { actionGroupId: actionGroupWarning.id }
      ]
    }
  }
  tags: { Environment: environment, ManagedBy: 'platform-team' }
}

// ─── Policy Non-Compliance Alert ─────────────────────────────────────────────
resource policyNonComplianceAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'alert-policy-noncompliance-${environment}'
  location: location
  properties: {
    displayName: 'Governance: New Non-Compliant Resources Detected'
    description: 'Alert when new resources are detected as non-compliant with assigned Azure Policies'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT1H'
    windowSize: 'PT1H'
    scopes: [logAnalyticsWorkspaceId]
    criteria: {
      allOf: [
        {
          query: '''
            AzureActivity
            | where OperationNameValue == "MICROSOFT.AUTHORIZATION/POLICIES/DENY/ACTION"
            | where ActivityStatusValue == "Failure"
            | project TimeGenerated, Caller, ResourceId, OperationNameValue
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
      actionGroups: [actionGroupWarning.id]
      customProperties: { AlertType: 'Governance' }
    }
  }
}

// ─── Outputs ─────────────────────────────────────────────────────────────────
output criticalActionGroupId string = actionGroupCritical.id
output warningActionGroupId string = actionGroupWarning.id
