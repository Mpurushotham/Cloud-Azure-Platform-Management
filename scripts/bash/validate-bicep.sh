#!/usr/bin/env bash
# validate-bicep.sh — Lint and validate all Bicep templates in the repository
set -euo pipefail

echo "=== Bicep Validation ==="
FAILED=0
PASSED=0
TOTAL=0

# Ensure Bicep is installed
if ! command -v az &>/dev/null; then
    echo "ERROR: Azure CLI not found. Run: bash scripts/bash/setup.sh"
    exit 1
fi
az bicep install 2>/dev/null || true

echo ""
echo "Building all .bicep files..."
while IFS= read -r -d '' file; do
    TOTAL=$((TOTAL + 1))
    if az bicep build --file "$file" --stdout > /dev/null 2>&1; then
        echo "  ✓ $file"
        PASSED=$((PASSED + 1))
    else
        echo "  ✗ FAILED: $file"
        az bicep build --file "$file" --stdout 2>&1 | head -20
        FAILED=$((FAILED + 1))
    fi
done < <(find . -name "*.bicep" -not -path "./.git/*" -print0)

echo ""
echo "=== Results ==="
echo "  Total:  $TOTAL"
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"

if [ $FAILED -ne 0 ]; then
    echo ""
    echo "ERROR: $FAILED Bicep file(s) failed validation. Fix errors before committing."
    exit 1
fi

echo ""
echo "All Bicep files validated successfully."
