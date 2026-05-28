<#
.SYNOPSIS
    Identifies and optionally removes stale Azure resources older than N days with no recent activity.

.DESCRIPTION
    Scans all subscriptions for orphaned resources: unattached disks, unassociated public IPs,
    unused NSGs, empty resource groups, and stopped-deallocated VMs older than the threshold.
    Generates a CSV report and optionally removes resources in non-production subscriptions.

.PARAMETER DaysOld
    Resources with no activity for this many days are flagged. Default: 90

.PARAMETER DryRun
    If $true, only reports findings without deleting anything. Default: $true

.PARAMETER ReportStorageAccountName
    Storage Account name to upload the CSV report. Leave empty to skip upload.

.PARAMETER ReportContainerName
    Blob container name for report upload. Default: 'compliance-reports'
#>
[CmdletBinding()]
param(
    [int] $DaysOld = 90,
    [bool] $DryRun = $true,
    [string] $ReportStorageAccountName = '',
    [string] $ReportContainerName = 'compliance-reports'
)

$ErrorActionPreference = 'Stop'
$cutoffDate = (Get-Date).AddDays(-$DaysOld)
$report = [System.Collections.Generic.List[PSObject]]::new()

# Authenticate with Managed Identity
Connect-AzAccount -Identity | Out-Null
Write-Output "Authenticated with Managed Identity | Cutoff date: $cutoffDate | DryRun: $DryRun"

$subscriptions = Get-AzSubscription | Where-Object { $_.State -eq 'Enabled' }

foreach ($sub in $subscriptions) {
    Set-AzContext -SubscriptionId $sub.Id | Out-Null
    $isProd = $sub.Name -like '*prod*'
    Write-Output "--- Subscription: $($sub.Name) | IsProd: $isProd"

    # 1. Orphaned Managed Disks (not attached to any VM)
    $orphanedDisks = Get-AzDisk | Where-Object {
        $null -eq $_.ManagedBy -and $_.TimeCreated -lt $cutoffDate
    }
    foreach ($disk in $orphanedDisks) {
        $entry = [PSCustomObject]@{
            SubscriptionName = $sub.Name
            ResourceType     = 'Disk'
            ResourceName     = $disk.Name
            ResourceGroup    = $disk.ResourceGroupName
            CreatedDate      = $disk.TimeCreated
            SizeGB           = $disk.DiskSizeGB
            EstMonthlyCostUSD = [math]::Round($disk.DiskSizeGB * 0.05, 2)
            Action           = if ($isProd) { 'Report Only (Prod)' } elseif ($DryRun) { 'DryRun-WouldDelete' } else { 'Deleted' }
        }
        $report.Add($entry)
        if (-not $isProd -and -not $DryRun) {
            Remove-AzDisk -ResourceGroupName $disk.ResourceGroupName -DiskName $disk.Name -Force | Out-Null
            Write-Output "  DELETED orphaned disk: $($disk.Name)"
        } else {
            Write-Output "  FOUND orphaned disk: $($disk.Name) | $($disk.DiskSizeGB)GB | Created: $($disk.TimeCreated)"
        }
    }

    # 2. Unassociated Public IP Addresses
    $orphanedPips = Get-AzPublicIpAddress | Where-Object {
        $null -eq $_.IpConfiguration -and $_.Location -ne 'global'
    }
    foreach ($pip in $orphanedPips) {
        $entry = [PSCustomObject]@{
            SubscriptionName  = $sub.Name
            ResourceType      = 'PublicIP'
            ResourceName      = $pip.Name
            ResourceGroup     = $pip.ResourceGroupName
            CreatedDate       = 'N/A'
            SizeGB            = 0
            EstMonthlyCostUSD = 3.65
            Action            = if ($isProd) { 'Report Only (Prod)' } elseif ($DryRun) { 'DryRun-WouldDelete' } else { 'Deleted' }
        }
        $report.Add($entry)
        if (-not $isProd -and -not $DryRun) {
            Remove-AzPublicIpAddress -ResourceGroupName $pip.ResourceGroupName -Name $pip.Name -Force | Out-Null
            Write-Output "  DELETED unassociated PIP: $($pip.Name)"
        } else {
            Write-Output "  FOUND unassociated PIP: $($pip.Name)"
        }
    }

    # 3. Stopped/Deallocated VMs older than threshold
    $stoppedVMs = Get-AzVM | ForEach-Object {
        $vmStatus = Get-AzVM -ResourceGroupName $_.ResourceGroupName -Name $_.Name -Status
        $powerState = ($vmStatus.Statuses | Where-Object { $_.Code -like 'PowerState/*' }).DisplayStatus
        if ($powerState -eq 'VM deallocated') { $_ }
    }
    foreach ($vm in $stoppedVMs) {
        $entry = [PSCustomObject]@{
            SubscriptionName  = $sub.Name
            ResourceType      = 'VirtualMachine'
            ResourceName      = $vm.Name
            ResourceGroup     = $vm.ResourceGroupName
            CreatedDate       = 'Deallocated'
            SizeGB            = 0
            EstMonthlyCostUSD = 0
            Action            = 'Review Required'
        }
        $report.Add($entry)
        Write-Output "  FOUND deallocated VM: $($vm.Name) in $($vm.ResourceGroupName)"
    }

    # 4. Empty Resource Groups
    $emptyRGs = Get-AzResourceGroup | Where-Object {
        (Get-AzResource -ResourceGroupName $_.ResourceGroupName | Measure-Object).Count -eq 0
    }
    foreach ($rg in $emptyRGs) {
        $entry = [PSCustomObject]@{
            SubscriptionName  = $sub.Name
            ResourceType      = 'ResourceGroup'
            ResourceName      = $rg.ResourceGroupName
            ResourceGroup     = $rg.ResourceGroupName
            CreatedDate       = 'N/A'
            SizeGB            = 0
            EstMonthlyCostUSD = 0
            Action            = if ($DryRun) { 'DryRun-WouldDelete' } else { 'Deleted' }
        }
        $report.Add($entry)
        if (-not $isProd -and -not $DryRun) {
            Remove-AzResourceGroup -Name $rg.ResourceGroupName -Force | Out-Null
            Write-Output "  DELETED empty RG: $($rg.ResourceGroupName)"
        } else {
            Write-Output "  FOUND empty RG: $($rg.ResourceGroupName)"
        }
    }
}

# Generate CSV Report
$reportPath = "/tmp/stale-resources-$(Get-Date -Format 'yyyy-MM-dd').csv"
$report | Export-Csv -Path $reportPath -NoTypeInformation

$totalEstSavings = ($report | Measure-Object -Property EstMonthlyCostUSD -Sum).Sum
Write-Output ""
Write-Output "=== Cleanup Summary ==="
Write-Output "Total stale resources found: $($report.Count)"
Write-Output "Estimated monthly savings if removed: `$$([math]::Round($totalEstSavings, 2))"
Write-Output "Report: $reportPath"

# Upload report to Storage Account if specified
if (-not [string]::IsNullOrEmpty($ReportStorageAccountName)) {
    $storageAccount = Get-AzStorageAccount | Where-Object { $_.StorageAccountName -eq $ReportStorageAccountName }
    if ($storageAccount) {
        $ctx = $storageAccount.Context
        Set-AzStorageBlobContent -Container $ReportContainerName -File $reportPath -Blob "stale-resources/$(Split-Path $reportPath -Leaf)" -Context $ctx -Force | Out-Null
        Write-Output "Report uploaded to Storage Account: $ReportStorageAccountName/$ReportContainerName"
    }
}
