targetScope = 'tenant'

@description('Prefix for all management group display names')
param mgmtGroupPrefix string = 'Contoso'

@description('Top-level root management group ID (tenant ID)')
param rootMgId string

// ─── Management Group Hierarchy ─────────────────────────────────────────────
// Root
//  └── Platform
//      ├── Identity
//      ├── Management
//      └── Connectivity
//  └── LandingZones
//      ├── Corp
//      └── Online
//  └── Sandbox
//  └── Decommissioned

resource mg_platform 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: '${mgmtGroupPrefix}-Platform'
  properties: {
    displayName: '${mgmtGroupPrefix} Platform'
    details: {
      parent: {
        id: tenantResourceId('Microsoft.Management/managementGroups', rootMgId)
      }
    }
  }
}

resource mg_identity 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: '${mgmtGroupPrefix}-Identity'
  properties: {
    displayName: '${mgmtGroupPrefix} Identity'
    details: {
      parent: {
        id: mg_platform.id
      }
    }
  }
}

resource mg_management 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: '${mgmtGroupPrefix}-Management'
  properties: {
    displayName: '${mgmtGroupPrefix} Management'
    details: {
      parent: {
        id: mg_platform.id
      }
    }
  }
}

resource mg_connectivity 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: '${mgmtGroupPrefix}-Connectivity'
  properties: {
    displayName: '${mgmtGroupPrefix} Connectivity'
    details: {
      parent: {
        id: mg_platform.id
      }
    }
  }
}

resource mg_landingzones 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: '${mgmtGroupPrefix}-LandingZones'
  properties: {
    displayName: '${mgmtGroupPrefix} Landing Zones'
    details: {
      parent: {
        id: tenantResourceId('Microsoft.Management/managementGroups', rootMgId)
      }
    }
  }
}

resource mg_corp 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: '${mgmtGroupPrefix}-Corp'
  properties: {
    displayName: '${mgmtGroupPrefix} Corp'
    details: {
      parent: {
        id: mg_landingzones.id
      }
    }
  }
}

resource mg_online 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: '${mgmtGroupPrefix}-Online'
  properties: {
    displayName: '${mgmtGroupPrefix} Online'
    details: {
      parent: {
        id: mg_landingzones.id
      }
    }
  }
}

resource mg_sandbox 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: '${mgmtGroupPrefix}-Sandbox'
  properties: {
    displayName: '${mgmtGroupPrefix} Sandbox'
    details: {
      parent: {
        id: tenantResourceId('Microsoft.Management/managementGroups', rootMgId)
      }
    }
  }
}

resource mg_decommissioned 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: '${mgmtGroupPrefix}-Decommissioned'
  properties: {
    displayName: '${mgmtGroupPrefix} Decommissioned'
    details: {
      parent: {
        id: tenantResourceId('Microsoft.Management/managementGroups', rootMgId)
      }
    }
  }
}

// ─── Outputs ────────────────────────────────────────────────────────────────
output platformMgId string = mg_platform.id
output identityMgId string = mg_identity.id
output managementMgId string = mg_management.id
output connectivityMgId string = mg_connectivity.id
output landingZonesMgId string = mg_landingzones.id
output corpMgId string = mg_corp.id
output onlineMgId string = mg_online.id
output sandboxMgId string = mg_sandbox.id
output decommissionedMgId string = mg_decommissioned.id
