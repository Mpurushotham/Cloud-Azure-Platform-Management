param location string
param ddosPlanName string
param environment string

resource ddosPlan 'Microsoft.Network/ddosProtectionPlans@2023-06-01' = {
  name: ddosPlanName
  location: location
  tags: {
    Environment: environment
    ManagedBy: 'platform-team'
    Application: 'hub-connectivity'
    CostCenter: 'CC-PLATFORM'
    Owner: 'platform-team@contoso.com'
  }
}

output ddosPlanId string = ddosPlan.id
