<#
.SYNOPSIS
    Queries Azure Policy compliance state across all subscriptions and exports a report.

.DESCRIPTION
    Iterates over all subscriptions, retrieves non-compliant resources for all assigned policies,
    and exports a detailed CSV report to a Storage Account. Designed as an Azure Automation runbook
    scheduled to run weekly.

.PARAMETER ReportStorageAccountName
    Storage Account name to upload compliance report.

.PARAMETER ReportContainerName
    Blob container for the report. Default: 'compliance-reports'

.PARAMETER NonCompliantOnly
    If $true, only reports non-compliant resources. Default: $true
#>
[CmdletBinding()]
param(
    [string] $ReportStorageAccountName = '',
    [string] $ReportContainerName = 'compliance-reports',
    [bool] $NonCompliantOnly = $true
)

$ErrorActionPreference = 'Stop'
$report = [System.Collections.Generic.List[PSObject]]::new()
$dateStamp = Get-Date -Format 'yyyy-MM-dd'

Connect-AzAccount -Identity | Out-Null
Write-Output "Authenticated. Generating policy compliance report..."

$subscriptions = Get-AzSubscription | Where-Object { $_.State -eq 'Enabled' }

foreach ($sub in $subscriptions) {
    Set-AzContext -SubscriptionId $sub.Id | Out-Null
    Write-Output "--- Subscription: $($sub.Name)"

    $filter = if ($NonCompliantOnly) { "complianceState eq 'NonCompliant'" } else { $null }
    $states = if ($null -eq $filter) {
        Get-AzPolicyState -Top 1000
    } else {
        Get-AzPolicyState -Filter $filter -Top 1000
    }

    foreach ($state in $states) {
        $entry = [PSCustomObject]@{
            ReportDate            = $dateStamp
            SubscriptionName      = $sub.Name
            SubscriptionId        = $sub.Id
            PolicyDefinitionName  = $state.PolicyDefinitionName
            PolicyAssignmentName  = $state.PolicyAssignmentName
            ComplianceState       = $state.ComplianceState
            ResourceId            = $state.ResourceId
            ResourceType          = $state.ResourceType
            ResourceGroup         = $state.ResourceGroup
            Timestamp             = $state.Timestamp
        }
        $report.Add($entry)
    }
    Write-Output "  Found $($states.Count) policy states"
}

# Summary
$nonCompliantCount = ($report | Where-Object { $_.ComplianceState -eq 'NonCompliant' }).Count
$totalCount = $report.Count
Write-Output ""
Write-Output "=== Compliance Summary ==="
Write-Output "Total resources evaluated: $totalCount"
Write-Output "Non-compliant resources: $nonCompliantCount"
Write-Output "Compliance rate: $([math]::Round((($totalCount - $nonCompliantCount) / [math]::Max($totalCount, 1)) * 100, 2))%"

# Export CSV
$reportPath = "/tmp/policy-compliance-${dateStamp}.csv"
$report | Export-Csv -Path $reportPath -NoTypeInformation
Write-Output "Report saved: $reportPath"

# Upload to Storage Account
if (-not [string]::IsNullOrEmpty($ReportStorageAccountName)) {
    $storageAccount = Get-AzStorageAccount | Where-Object { $_.StorageAccountName -eq $ReportStorageAccountName } | Select-Object -First 1
    if ($storageAccount) {
        $ctx = $storageAccount.Context
        $blobName = "policy-compliance/${dateStamp}-compliance-report.csv"
        Set-AzStorageBlobContent -Container $ReportContainerName -File $reportPath -Blob $blobName -Context $ctx -Force | Out-Null
        Write-Output "Report uploaded: $ReportStorageAccountName/$ReportContainerName/$blobName"
    } else {
        Write-Warning "Storage account '$ReportStorageAccountName' not found. Report not uploaded."
    }
}

if ($nonCompliantCount -gt 0) {
    Write-Warning "$nonCompliantCount non-compliant resources found. Review the report and trigger remediation tasks."
}
