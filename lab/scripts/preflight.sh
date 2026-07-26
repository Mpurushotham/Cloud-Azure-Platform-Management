#!/usr/bin/env bash
# preflight.sh — assert the lab's assumptions before spending credit.
# READ-ONLY. Exits non-zero on anything that would make `terraform apply` fail.
#
# Usage: bash lab/scripts/preflight.sh [region] [vm_size]
set -euo pipefail

REGION="${1:-eastus}"
VM_SIZE="${2:-Standard_D2as_v7}"
NEEDED_VCPU=2
FAIL=0

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=1; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }

echo "=== Lab preflight — region: $REGION ==="
echo

# ─── 1. Tooling ──────────────────────────────────────────────────────────────
echo "[1/6] Local tooling"
for t in az terraform kubectl; do
    if command -v "$t" >/dev/null 2>&1; then ok "$t present"; else bad "$t MISSING"; fi
done
command -v docker >/dev/null 2>&1 && ok "docker present" \
    || warn "docker absent — fine, we use 'az acr build' (server-side)"

# ─── 2. Authentication ───────────────────────────────────────────────────────
echo
echo "[2/6] Azure login"
if ! ACCOUNT=$(az account show -o json 2>/dev/null); then
    bad "not logged in — run: az login"
    exit 1
fi
SUB_ID=$(echo "$ACCOUNT"   | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')
SUB_NAME=$(echo "$ACCOUNT" | python3 -c 'import json,sys;print(json.load(sys.stdin)["name"])')
SUB_STATE=$(echo "$ACCOUNT"| python3 -c 'import json,sys;print(json.load(sys.stdin)["state"])')
ok "subscription: $SUB_NAME ($SUB_ID)"
[ "$SUB_STATE" = "Enabled" ] && ok "state: Enabled" || bad "state: $SUB_STATE — credit may be exhausted"

# ─── 3. Spending limit (our $0 guarantee) ────────────────────────────────────
echo
echo "[3/6] Cost guard-rails"
POLICY=$(az rest --method get \
    --url "https://management.azure.com/subscriptions/${SUB_ID}?api-version=2020-01-01" \
    -o json 2>/dev/null || echo '{}')
SPEND=$(echo "$POLICY" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("subscriptionPolicies",{}).get("spendingLimit","unknown"))' 2>/dev/null || echo unknown)
QUOTA=$(echo "$POLICY" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("subscriptionPolicies",{}).get("quotaId","unknown"))' 2>/dev/null || echo unknown)
if [ "$SPEND" = "On" ]; then
    ok "spending limit ON — you cannot be charged real money"
else
    warn "spending limit is '$SPEND' — REAL CHARGES ARE POSSIBLE. Know your budget."
fi
echo "      offer: $QUOTA"
case "$QUOTA" in
    FreeTrial*) warn "FreeTrial: Microsoft.Consumption/budgets is NOT supported — teardown discipline is your only cost control" ;;
esac

# ─── 4. SKU availability AND quota ───────────────────────────────────────────
# Two independent gates. An earlier version of this script only checked quota
# and happily passed for Standard_B2s — then AKS rejected the apply with
# "The VM size of Standard_B2s is not allowed in your subscription in location
# 'eastus'". Quota says "how much you may use"; availability says "whether this
# subscription is offered the SKU here at all". Check both.
echo
echo "[4/6] Node SKU '$VM_SIZE' in $REGION"

SKU_JSON=$(az vm list-skus --location "$REGION" --resource-type virtualMachines \
             --size "$VM_SIZE" -o json 2>/dev/null || echo '[]')
SKU_INFO=$(echo "$SKU_JSON" | python3 -c "
import json,sys
want=sys.argv[1]
for s in json.load(sys.stdin):
    if s['name']!=want: continue
    caps={c['name']:c['value'] for c in s.get('capabilities',[])}
    r=[x.get('reasonCode','?') for x in (s.get('restrictions') or [])]
    print(f\"{caps.get('vCPUs','?')}|{caps.get('MemoryGB','?')}|{s['family']}|{','.join(r) if r else 'NONE'}\")
    break
else:
    print('||NOT_OFFERED|')" "$VM_SIZE")

SKU_VCPU=$(echo "$SKU_INFO" | cut -d'|' -f1)
SKU_RAM=$(echo  "$SKU_INFO" | cut -d'|' -f2)
SKU_FAMILY=$(echo "$SKU_INFO" | cut -d'|' -f3)
SKU_RESTR=$(echo  "$SKU_INFO" | cut -d'|' -f4)

if [ "$SKU_FAMILY" = "NOT_OFFERED" ]; then
    bad "$VM_SIZE is NOT offered to this subscription in $REGION"
    echo "      Available 2-vCPU alternatives here:"
    az vm list-skus --location "$REGION" --resource-type virtualMachines -o json 2>/dev/null \
      | python3 -c "
import json,sys
out=[]
for s in json.load(sys.stdin):
    caps={c['name']:c['value'] for c in s.get('capabilities',[])}
    if caps.get('vCPUs')=='2' and not (s.get('restrictions') or []):
        out.append((s['name'],caps.get('MemoryGB'),s['family']))
for n,m,f in sorted(out)[:12]: print(f'        {n:<22} {m} GiB   {f}')" || true
elif [ "$SKU_RESTR" != "NONE" ]; then
    bad "$VM_SIZE is restricted in $REGION: $SKU_RESTR"
else
    ok "$VM_SIZE offered here — ${SKU_VCPU} vCPU, ${SKU_RAM} GiB, family $SKU_FAMILY"
fi

USAGE=$(az vm list-usage --location "$REGION" -o json 2>/dev/null || echo '[]')
read_quota() {
    echo "$USAGE" | python3 -c "
import json,sys
want=sys.argv[1].lower()
for u in json.load(sys.stdin):
    if u['name']['value'].lower()==want: print(f\"{u['currentValue']} {u['limit']}\"); break
else: print('0 0')" "$1"
}
set -- $(read_quota cores); TOTAL_CUR=$1; TOTAL_MAX=$2
echo "      Total regional vCPUs : ${TOTAL_CUR}/${TOTAL_MAX}"
if [ "$SKU_FAMILY" != "NOT_OFFERED" ] && [ -n "$SKU_FAMILY" ]; then
    set -- $(read_quota "$SKU_FAMILY"); FAM_CUR=$1; FAM_MAX=$2
    echo "      $SKU_FAMILY : ${FAM_CUR}/${FAM_MAX}"
    if [ "$(( FAM_MAX - FAM_CUR ))" -ge "$NEEDED_VCPU" ]; then
        ok "family quota has room for ${NEEDED_VCPU} vCPU"
    else
        bad "family quota exhausted: need ${NEEDED_VCPU}, have $(( FAM_MAX - FAM_CUR ))"
    fi
fi
AVAIL=$(( TOTAL_MAX - TOTAL_CUR ))
if [ "$AVAIL" -ge "$NEEDED_VCPU" ]; then
    ok "regional quota has room (${AVAIL} vCPU free)"
else
    bad "regional quota exhausted: need ${NEEDED_VCPU} vCPU, have ${AVAIL}"
fi
[ "$TOTAL_MAX" -le 4 ] && warn "quota is ${TOTAL_MAX} vCPU — AKS default (3 x DS2_v2 = 6) WILL fail; node_count must stay 1"

# ─── 5. Resource providers ───────────────────────────────────────────────────
echo
echo "[5/6] Resource provider registration"
UNREG=()
for p in Microsoft.ContainerService Microsoft.ContainerRegistry \
         Microsoft.OperationalInsights Microsoft.Insights Microsoft.Network; do
    STATE=$(az provider show --namespace "$p" --query registrationState -o tsv 2>/dev/null || echo unknown)
    if [ "$STATE" = "Registered" ]; then ok "$p"; else bad "$p = $STATE"; UNREG+=("$p"); fi
done
if [ ${#UNREG[@]} -gt 0 ]; then
    echo
    echo "      Register them with:"
    for p in "${UNREG[@]}"; do echo "        az provider register --namespace $p"; done
    echo "      (takes 1-2 min each; poll with 'az provider show -n <ns> --query registrationState')"
fi

# ─── 6. Existing lab resources (cost already accruing?) ──────────────────────
echo
echo "[6/6] Existing lab footprint"
EXISTING=$(az group list --query "[?starts_with(name,'rg-lab-')].name" -o tsv 2>/dev/null || true)
if [ -z "$EXISTING" ]; then
    ok "no rg-lab-* groups — clean slate, nothing billing"
else
    warn "lab resource groups already exist (may be costing credit):"
    echo "$EXISTING" | sed 's/^/        /'
    echo "      destroy with: bash lab/scripts/teardown.sh"
fi

echo
if [ "$FAIL" -ne 0 ]; then
    echo "=== PREFLIGHT FAILED — fix the ✗ items above before applying ==="
    exit 1
fi
echo "=== PREFLIGHT PASSED — safe to 'terraform apply' ==="
