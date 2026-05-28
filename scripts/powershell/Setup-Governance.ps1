<#
.SYNOPSIS
    Bootstraps the full Azure governance hierarchy: management groups, custom RBAC roles,
    policy definitions, policy initiatives, and initial assignments.

.DESCRIPTION
    One-time setup script run by the platform team to initialize governance infrastructure
    before any Bicep/Terraform deployments. Requires Owner on the tenant root management group.

.PARAMETER TenantId
    Azure Entra ID Tenant ID.

.PARAMETER RootMgId
    Root Management Group ID (usually the Tenant ID).

.PARAMETER MgmtGroupPrefix
    Prefix for management group display names. Default: 'Contoso'

.PARAMETER DryRun
    If $true, shows what would be created without making changes.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $TenantId,

    [Parameter(Mandatory = $true)]
    [string] $RootMgId,

    [string] $MgmtGroupPrefix = 'Contoso',

    [bool] $DryRun = $false
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Cloud-Azure-Platform-Management — Governance Bootstrap ===" -ForegroundColor Cyan
Write-Host "TenantId: $TenantId | RootMgId: $RootMgId | Prefix: $MgmtGroupPrefix | DryRun: $DryRun"

# ─── Authenticate ──────────────────────────────────────────────────────────────
try {
    Connect-AzAccount -TenantId $TenantId | Out-Null
    Write-Host "Authenticated to Azure tenant: $TenantId" -ForegroundColor Green
} catch {
    Write-Error "Authentication failed: $_"
    exit 1
}

# ─── Step 1: Deploy Management Group Hierarchy ────────────────────────────────
Write-Host "`n[1/5] Deploying Management Group hierarchy..." -ForegroundColor Yellow

if (-not $DryRun) {
    $mgDeployment = New-AzTenantDeployment `
        -Location 'eastus' `
        -TemplateFile "$PSScriptRoot/../../governance/management-groups/main.bicep" `
        -TemplateParameterObject @{
            mgmtGroupPrefix = $MgmtGroupPrefix
            rootMgId = $RootMgId
        } `
        -Name "governance-mg-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Write-Host "  Management group hierarchy deployed: $($mgDeployment.ProvisioningState)" -ForegroundColor Green
} else {
    Write-Host "  [DRY RUN] Would deploy management group hierarchy" -ForegroundColor Gray
}

# ─── Step 2: Create Custom RBAC Role Definitions ─────────────────────────────
Write-Host "`n[2/5] Creating custom RBAC role definitions..." -ForegroundColor Yellow

$roleFiles = Get-ChildItem "$PSScriptRoot/../../governance/rbac/custom-roles/*.json"
foreach ($roleFile in $roleFiles) {
    $roleDef = Get-Content $roleFile.FullName | ConvertFrom-Json
    Write-Host "  Role: $($roleDef.Name)"
    if (-not $DryRun) {
        $existing = Get-AzRoleDefinition -Name $roleDef.Name -ErrorAction SilentlyContinue
        if ($null -eq $existing) {
            New-AzRoleDefinition -InputFile $roleFile.FullName | Out-Null
            Write-Host "  → Created: $($roleDef.Name)" -ForegroundColor Green
        } else {
            Set-AzRoleDefinition -InputFile $roleFile.FullName | Out-Null
            Write-Host "  → Updated: $($roleDef.Name)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [DRY RUN] Would create/update role: $($roleDef.Name)" -ForegroundColor Gray
    }
}

# ─── Step 3: Deploy Custom Policy Definitions ─────────────────────────────────
Write-Host "`n[3/5] Deploying custom Azure Policy definitions..." -ForegroundColor Yellow

$policyFiles = Get-ChildItem "$PSScriptRoot/../../governance/policies/custom/*.json"
foreach ($policyFile in $policyFiles) {
    $policy = Get-Content $policyFile.FullName | ConvertFrom-Json
    Write-Host "  Policy: $($policy.name)"
    if (-not $DryRun) {
        $existingPolicy = Get-AzPolicyDefinition -ManagementGroupName $RootMgId -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq $policy.name }
        if ($null -eq $existingPolicy) {
            New-AzPolicyDefinition `
                -Name $policy.name `
                -ManagementGroupName $RootMgId `
                -Policy $policyFile.FullName | Out-Null
            Write-Host "  → Created: $($policy.name)" -ForegroundColor Green
        } else {
            Write-Host "  → Already exists: $($policy.name) (skipped)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  [DRY RUN] Would deploy policy: $($policy.name)" -ForegroundColor Gray
    }
}

# ─── Step 4: Deploy Policy Initiatives ───────────────────────────────────────
Write-Host "`n[4/5] Deploying policy initiatives..." -ForegroundColor Yellow
$initiativeFiles = Get-ChildItem "$PSScriptRoot/../../governance/policies/initiatives/*.json"
foreach ($initFile in $initiativeFiles) {
    $initiative = Get-Content $initFile.FullName | ConvertFrom-Json
    Write-Host "  Initiative: $($initiative.name)"
    if (-not $DryRun) {
        Write-Host "  → Creating initiative: $($initiative.name)" -ForegroundColor Green
        # Initiative creation via REST API (az CLI doesn't have a direct command)
        az policy set-definition create `
            --name $initiative.name `
            --management-group $RootMgId `
            --definitions ($initFile.FullName) `
            --display-name $initiative.properties.displayName 2>$null | Out-Null
    } else {
        Write-Host "  [DRY RUN] Would create initiative: $($initiative.name)" -ForegroundColor Gray
    }
}

# ─── Step 5: Summary ──────────────────────────────────────────────────────────
Write-Host "`n[5/5] Governance bootstrap complete." -ForegroundColor Cyan
Write-Host "Next steps:"
Write-Host "  1. Deploy hub networking: az deployment sub create --template-file networking/hub/main.bicep"
Write-Host "  2. Onboard subscriptions: pwsh scripts/powershell/Deploy-LandingZone.ps1 -LandingZoneType Corp"
Write-Host "  3. Enable GitHub Actions OIDC: register app in Entra ID with federated credentials"
