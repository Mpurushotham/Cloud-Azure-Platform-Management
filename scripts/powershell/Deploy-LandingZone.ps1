<#
.SYNOPSIS
    Onboards a new Azure subscription into a landing zone.

.DESCRIPTION
    Automates the subscription vending process: moves the subscription to the correct
    management group, deploys the landing zone Bicep template, and configures RBAC.

.PARAMETER LandingZoneType
    'Corp', 'Online', or 'Sandbox'

.PARAMETER SubscriptionId
    Target Azure subscription ID to onboard.

.PARAMETER WorkloadName
    Short workload name (used in resource naming, e.g. 'payments', 'auth-service').

.PARAMETER OwnerEmail
    Team or individual email address for the landing zone owner.

.PARAMETER SpokeAddressPrefix
    CIDR for the spoke VNet (e.g. 10.10.0.0/16). Must not overlap with existing spokes.

.PARAMETER HubVnetId
    Resource ID of the hub VNet to peer with (Corp and Online only).

.PARAMETER FirewallPrivateIp
    Private IP of Azure Firewall in hub (Corp and Online only).

.PARAMETER LogAnalyticsWorkspaceId
    Log Analytics workspace resource ID for diagnostics.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Corp', 'Online', 'Sandbox')]
    [string] $LandingZoneType,

    [Parameter(Mandatory = $true)]
    [string] $SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string] $WorkloadName,

    [Parameter(Mandatory = $true)]
    [string] $OwnerEmail,

    [string] $SpokeAddressPrefix = '10.10.0.0/16',
    [string] $HubVnetId = '',
    [string] $FirewallPrivateIp = '10.0.0.4',
    [string] $LogAnalyticsWorkspaceId = '',
    [string] $Environment = 'prod',
    [bool] $DryRun = $false
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Landing Zone Vending: $LandingZoneType | $WorkloadName | $SubscriptionId ===" -ForegroundColor Cyan

# ─── Step 1: Validate subscription access ─────────────────────────────────────
Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
$sub = Get-AzSubscription -SubscriptionId $SubscriptionId
Write-Host "Subscription: $($sub.Name) | State: $($sub.State)"
if ($sub.State -ne 'Enabled') {
    Write-Error "Subscription $SubscriptionId is not enabled (state: $($sub.State))"
    exit 1
}

# ─── Step 2: Move subscription to correct Management Group ───────────────────
Write-Host "`n[1/4] Moving subscription to $LandingZoneType Management Group..."
$mgName = "Contoso-$LandingZoneType"
if (-not $DryRun) {
    New-AzManagementGroupSubscription -GroupId $mgName -SubscriptionId $SubscriptionId
    Write-Host "  → Moved to MG: $mgName" -ForegroundColor Green
} else {
    Write-Host "  [DRY RUN] Would move to MG: $mgName" -ForegroundColor Gray
}

# ─── Step 3: Deploy Landing Zone Bicep ──────────────────────────────────────
Write-Host "`n[2/4] Deploying $LandingZoneType landing zone Bicep template..."
$templateFile = "$PSScriptRoot/../../landing-zones/$($LandingZoneType.ToLower())/main.bicep"
$deploymentName = "lz-$($WorkloadName.ToLower())-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

$params = @{
    location   = 'eastus'
    environment = $Environment
    workloadName = $WorkloadName
}

if ($LandingZoneType -in @('Corp', 'Online')) {
    $params['spokeAddressPrefix'] = $SpokeAddressPrefix
    $params['hubVnetId']          = $HubVnetId
    $params['firewallPrivateIp']  = $FirewallPrivateIp
    $params['logAnalyticsWorkspaceId'] = $LogAnalyticsWorkspaceId
} elseif ($LandingZoneType -eq 'Sandbox') {
    $params['ownerEmail']         = $OwnerEmail
    $params['logAnalyticsWorkspaceId'] = $LogAnalyticsWorkspaceId
}

if (-not $DryRun) {
    $deployment = New-AzSubscriptionDeployment `
        -Location 'eastus' `
        -TemplateFile $templateFile `
        -TemplateParameterObject $params `
        -Name $deploymentName
    Write-Host "  → Deployment status: $($deployment.ProvisioningState)" -ForegroundColor Green
} else {
    Write-Host "  [DRY RUN] Would run: New-AzSubscriptionDeployment -TemplateFile $templateFile" -ForegroundColor Gray
    Write-Host "  Params: $($params | ConvertTo-Json -Compress)"
}

# ─── Step 4: Assign Landing Zone Owner RBAC ──────────────────────────────────
Write-Host "`n[3/4] Assigning Landing Zone Owner RBAC role..."
$lzOwnerRoleId = '00000000-0000-0000-0000-000000000004'

if (-not $DryRun) {
    # Look up the owner's Entra ID object ID from email
    $ownerObj = Get-AzADUser -UserPrincipalName $OwnerEmail -ErrorAction SilentlyContinue
    if ($ownerObj) {
        New-AzRoleAssignment `
            -ObjectId $ownerObj.Id `
            -RoleDefinitionId $lzOwnerRoleId `
            -Scope "/subscriptions/$SubscriptionId" | Out-Null
        Write-Host "  → Assigned LZ Owner role to: $OwnerEmail" -ForegroundColor Green
    } else {
        Write-Warning "  Owner $OwnerEmail not found in Entra ID. RBAC assignment skipped."
    }
} else {
    Write-Host "  [DRY RUN] Would assign LZ Owner role to: $OwnerEmail" -ForegroundColor Gray
}

# ─── Step 5: Deploy Budget ────────────────────────────────────────────────────
Write-Host "`n[4/4] Deploying subscription budget..."
if (-not $DryRun) {
    New-AzSubscriptionDeployment `
        -Location 'eastus' `
        -TemplateFile "$PSScriptRoot/../../finops/budgets/main.bicep" `
        -TemplateParameterObject @{
            environment = $Environment
            workloadName = $WorkloadName
            notificationEmailAddress = $OwnerEmail
        } `
        -Name "budget-$WorkloadName-$(Get-Date -Format 'yyyyMMdd')" | Out-Null
    Write-Host "  → Budget deployed" -ForegroundColor Green
} else {
    Write-Host "  [DRY RUN] Would deploy budget for $Environment environment" -ForegroundColor Gray
}

Write-Host "`n=== Landing Zone '$WorkloadName' ($LandingZoneType) onboarded successfully ===" -ForegroundColor Cyan
Write-Host "Next: notify $OwnerEmail that subscription $SubscriptionId is ready."
