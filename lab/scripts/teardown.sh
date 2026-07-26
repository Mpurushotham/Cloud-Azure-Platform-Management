#!/usr/bin/env bash
# teardown.sh — return the lab to $0/hr. The most important script here.
#
#   bash lab/scripts/teardown.sh stop      # pause: deallocate AKS nodes, keep everything
#   bash lab/scripts/teardown.sh destroy   # true zero: terraform destroy
#   bash lab/scripts/teardown.sh nuke      # last resort: delete every rg-lab-* group
#
# 'stop' kills the dominant cost (node VMs) in seconds but disks, public IPs and
# ACR keep billing. 'destroy' is the only genuine zero.
set -euo pipefail

MODE="${1:-}"
TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform/environments/lab" && pwd)"

case "$MODE" in
  stop)
    echo "=== Pausing AKS (deallocates nodes; disks + PIP + ACR still bill) ==="
    found=0
    while read -r rg name; do
        [ -z "${name:-}" ] && continue
        found=1
        echo "  stopping $name in $rg ..."
        az aks stop --resource-group "$rg" --name "$name" --no-wait
    done < <(az aks list --query "[?starts_with(resourceGroup,'rg-lab-')].[resourceGroup,name]" -o tsv 2>/dev/null)
    [ "$found" -eq 0 ] && echo "  no lab clusters found."
    echo
    echo "Resume later with: az aks start -g <rg> -n <name>   (~2 min)"
    ;;

  destroy)
    echo "=== terraform destroy — true \$0 ==="
    if [ ! -d "$TF_DIR" ]; then echo "ERROR: $TF_DIR not found"; exit 1; fi
    cd "$TF_DIR"
    terraform destroy
    echo
    echo "Verifying nothing is left ..."
    left=$(az group list --query "[?starts_with(name,'rg-lab-')].name" -o tsv 2>/dev/null || true)
    if [ -z "$left" ]; then
        echo "  ✓ no rg-lab-* groups remain — billing stopped."
    else
        echo "  ! these remain (state drift?): $left"
        echo "    consider: bash lab/scripts/teardown.sh nuke"
    fi
    ;;

  nuke)
    echo "=== NUKE: delete every rg-lab-* resource group ==="
    echo "This bypasses Terraform. State will be stale afterwards —"
    echo "you will need 'terraform state rm' or to delete the state file."
    echo
    groups=$(az group list --query "[?starts_with(name,'rg-lab-')].name" -o tsv 2>/dev/null || true)
    if [ -z "$groups" ]; then echo "Nothing to delete."; exit 0; fi
    echo "Will DELETE:"; echo "$groups" | sed 's/^/  - /'
    echo
    read -r -p "Type 'delete' to confirm: " reply
    [ "$reply" = "delete" ] || { echo "Aborted."; exit 1; }
    while read -r g; do
        [ -z "$g" ] && continue
        echo "  deleting $g ..."
        az group delete --name "$g" --yes --no-wait
    done <<< "$groups"
    echo "Deletions queued (--no-wait). Poll with: az group list -o table"
    ;;

  *)
    cat <<'EOF'
Usage: bash lab/scripts/teardown.sh <stop|destroy|nuke>

  stop     Deallocate AKS node VMs. Fast, reversible, kills the biggest cost.
           Disks, public IPs and ACR CONTINUE to bill.
  destroy  terraform destroy — the only genuine $0. Use between practice sessions.
  nuke     Delete all rg-lab-* groups directly. Bypasses Terraform; leaves stale state.

Cost reminder (approx, eastus):
  Standard_B2s node   ~$0.042/hr   <- dominant; 'stop' or 'destroy' both kill it
  Standard public IP  ~$0.005/hr   <- only 'destroy'
  32 GiB managed disk ~$0.0016/hr  <- only 'destroy'
  ACR Basic           ~$0.167/day  <- only 'destroy'
EOF
    exit 1
    ;;
esac
