#!/usr/bin/env bash
# cleanup.sh — Identify and optionally remove stale dev/sandbox Azure resources
# Wraps the PowerShell runbook for CLI use.
set -euo pipefail

DAYS_OLD="${1:-90}"
DRY_RUN="${2:-true}"
ENVIRONMENT="${3:-sandbox}"

echo "=== Azure Resource Cleanup ==="
echo "Target: $ENVIRONMENT environments | Resources idle > $DAYS_OLD days | DryRun: $DRY_RUN"

if ! command -v az &>/dev/null; then
    echo "ERROR: Azure CLI required. Run: bash scripts/bash/setup.sh"
    exit 1
fi

if ! command -v pwsh &>/dev/null; then
    echo "ERROR: PowerShell required. Run: bash scripts/bash/setup.sh"
    exit 1
fi

# Run cleanup via PowerShell runbook
pwsh automation/runbooks/Cleanup-StaleResources.ps1 \
    -DaysOld "$DAYS_OLD" \
    -DryRun '$DRY_RUN'
