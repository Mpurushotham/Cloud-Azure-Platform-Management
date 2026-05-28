<#
.SYNOPSIS
    Starts or stops Azure Virtual Machines based on schedule tags.

.DESCRIPTION
    Iterates over all subscriptions in the management group hierarchy and starts/stops
    VMs that have the AutoShutdown:true tag. Designed to run as an Azure Automation runbook
    on a schedule (e.g., Start at 08:00 UTC, Stop at 18:00 UTC).

.PARAMETER Action
    'Start' or 'Stop'. Determines which action to take on tagged VMs.

.PARAMETER TagName
    Tag to check on VMs. Default: 'AutoShutdown'

.PARAMETER TagValue
    Tag value to match. Default: 'true'

.PARAMETER DryRun
    If $true, logs what would happen without making any changes.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Start', 'Stop')]
    [string] $Action,

    [string] $TagName = 'AutoShutdown',
    [string] $TagValue = 'true',
    [bool] $DryRun = $false
)

$ErrorActionPreference = 'Stop'

# Authenticate with Managed Identity (system-assigned on Automation Account)
try {
    Connect-AzAccount -Identity | Out-Null
    Write-Output "Authenticated with Managed Identity"
} catch {
    Write-Error "Failed to authenticate with Managed Identity: $_"
    exit 1
}

$subscriptions = Get-AzSubscription | Where-Object { $_.State -eq 'Enabled' }
Write-Output "Processing $($subscriptions.Count) subscriptions"

$totalVMs = 0
$actedOn = 0
$skipped = 0
$failed = 0

foreach ($sub in $subscriptions) {
    Set-AzContext -SubscriptionId $sub.Id | Out-Null
    Write-Output "--- Subscription: $($sub.Name) ($($sub.Id))"

    $vms = Get-AzVM | Where-Object { $_.Tags[$TagName] -eq $TagValue }
    $totalVMs += $vms.Count

    foreach ($vm in $vms) {
        $vmStatus = Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status
        $powerState = ($vmStatus.Statuses | Where-Object { $_.Code -like 'PowerState/*' }).DisplayStatus

        Write-Output "  VM: $($vm.Name) | RG: $($vm.ResourceGroupName) | State: $powerState"

        try {
            if ($Action -eq 'Stop') {
                if ($powerState -ne 'VM deallocated') {
                    if (-not $DryRun) {
                        Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force | Out-Null
                        Write-Output "  → STOPPED: $($vm.Name)"
                    } else {
                        Write-Output "  → [DRY RUN] Would STOP: $($vm.Name)"
                    }
                    $actedOn++
                } else {
                    Write-Output "  → Already stopped, skipping"
                    $skipped++
                }
            } elseif ($Action -eq 'Start') {
                if ($powerState -ne 'VM running') {
                    if (-not $DryRun) {
                        Start-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name | Out-Null
                        Write-Output "  → STARTED: $($vm.Name)"
                    } else {
                        Write-Output "  → [DRY RUN] Would START: $($vm.Name)"
                    }
                    $actedOn++
                } else {
                    Write-Output "  → Already running, skipping"
                    $skipped++
                }
            }
        } catch {
            Write-Warning "  → FAILED on $($vm.Name): $_"
            $failed++
        }
    }
}

Write-Output ""
Write-Output "=== Summary ==="
Write-Output "Total VMs with tag ${TagName}=${TagValue}: $totalVMs"
Write-Output "Action taken: $actedOn"
Write-Output "Skipped (already in desired state): $skipped"
Write-Output "Failed: $failed"
Write-Output "DryRun: $DryRun"

if ($failed -gt 0) {
    Write-Warning "$failed VMs failed to ${Action}. Review the logs above."
    exit 1
}
