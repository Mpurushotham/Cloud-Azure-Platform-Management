#!/usr/bin/env bash
# policy-compliance.sh — what would the baseline reject if it were enforcing?
#
# The Phase 3 loop:
#   1. assign audit-only (enforce = false)
#   2. run this, read what is non-compliant
#   3. exempt (not_scopes) or fix the workload
#   4. promote ONE control to Deny, re-run the lab apply as a regression test
#
# Usage: bash lab/scripts/policy-compliance.sh [--scan]
#        --scan  force a fresh evaluation first (a few minutes) instead of
#                reading the last cached result
set -euo pipefail

ASSIGNMENT="lab-baseline"
SUB_ID=$(az account show --query id -o tsv)

if [ "${1:-}" = "--scan" ]; then
    echo "Triggering evaluation (several minutes)..."
    az policy state trigger-scan 2>&1 | tail -1
    echo
fi

echo "=== Assignment posture ==="
az policy assignment show --name "$ASSIGNMENT" -o json 2>/dev/null | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: print('  assignment not found — has terraform apply run?'); sys.exit(0)
mode=d.get('enforcementMode','Default')
print(f\"  enforcementMode : {mode}\" + ('   <- AUDIT ONLY, denies nothing' if mode=='DoNotEnforce' else '   <- ENFORCING'))
for k,v in (d.get('parameters') or {}).items():
    print(f\"  {k:<17}: {v.get('value')}\")
ns=d.get('notScopes') or []
print(f\"  notScopes       : {len(ns)}\")
for s in ns: print(f\"      {s.rsplit('/',1)[-1]}\")
"

echo
echo "=== Compliance summary ==="
az policy state summarize --filter "PolicyAssignmentName eq '$ASSIGNMENT'" -o json 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
v=(d.get('value') or [{}])[0]
res=v.get('results') or {}
print(f\"  non-compliant resources : {res.get('nonCompliantResources',0)}\")
print(f\"  non-compliant policies  : {res.get('nonCompliantPolicies',0)}\")
" 2>/dev/null || echo "  (no results yet — evaluation may still be running)"

echo
echo "=== Non-compliant resources, by control ==="
# Fetch the assignment's last-modified time so stale records can be flagged.
# A resource added to not_scopes stops being evaluated, but its pre-exclusion
# NonCompliant record persists until it ages out — so 'state list' keeps
# reporting it while 'state summarize' (which reflects current scope) says 0.
# Without this marker you chase a violation that is already resolved.
CHANGED_AT=$(az policy assignment show --name "$ASSIGNMENT" \
    --query "systemData.lastModifiedAt" -o tsv 2>/dev/null || echo "")

az policy state list \
    --filter "PolicyAssignmentName eq '$ASSIGNMENT' and ComplianceState eq 'NonCompliant'" \
    --query "[].{ref:policyDefinitionReferenceId,type:resourceType,id:resourceId,ts:timestamp}" \
    -o json 2>/dev/null | CHANGED_AT="$CHANGED_AT" python3 -c "
import json,sys,collections,os,datetime
rows=json.load(sys.stdin)
changed=os.environ.get('CHANGED_AT') or ''
def stale(ts):
    if not (ts and changed): return False
    try:
        return datetime.datetime.fromisoformat(ts.replace('Z','+00:00')) < \
               datetime.datetime.fromisoformat(changed.replace('Z','+00:00'))
    except Exception:
        return False
if not rows:
    print('  none — either compliant, or evaluation has not finished yet.')
    sys.exit(0)
by=collections.defaultdict(list)
for r in rows:
    by[r.get('ref') or '(unknown)'].append(r)
any_live=False
for ref, items in sorted(by.items()):
    print(f'  {ref}  ({len(items)} resource(s))')
    for it in items[:8]:
        rid=it.get('id','')
        # Policy state returns resource IDs LOWERCASED, so a case-sensitive
        # split on '/resourceGroups/' never matches and every row showed 'rg=-'.
        low = rid.lower(); marker = '/resourcegroups/'
        rg = rid[low.index(marker)+len(marker):].split('/')[0] if marker in low else '-'
        st = stale(it.get('ts'))
        if not st: any_live=True
        flag = '  [STALE — evaluated before the last assignment change]' if st else ''
        print(f\"      {it.get('type','?'):<44} rg={rg}{flag}\")
    if len(items)>8: print(f'      ... and {len(items)-8} more')
    print()
if any_live:
    print('  If enforcementMode were Default, every non-stale line above would have been REJECTED.')
else:
    print('  All findings are STALE: they predate the current assignment, so they reflect')
    print('  scope or resources that have since been excluded or fixed. Cross-check against')
    print('  the summary above, which reflects the CURRENT scope. Stale records age out.')
"
