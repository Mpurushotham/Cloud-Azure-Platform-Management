#!/usr/bin/env bash
# bootstrap-oidc.sh — Phase 2 bootstrap: GitHub OIDC identity + Terraform remote state.
#
# Idempotent: safe to re-run. Creates nothing that already exists.
#
# Solves the chicken-and-egg that the enterprise tree never addresses: its
# terraform/environments/*/backend.tf reference a storage account
# (stterraformstatedev001) that nothing in the repo creates, with a hardcoded
# globally-unique name that is almost certainly taken. Here the name is derived
# from your subscription id, so it is unique to you and stable across re-runs.
#
# Usage: bash lab/scripts/bootstrap-oidc.sh [github_owner/repo]
set -euo pipefail

REPO="${1:-$(gh repo view --json owner,name -q '.owner.login + "/" + .name' 2>/dev/null || echo '')}"
[ -z "$REPO" ] && { echo "ERROR: pass owner/repo or run inside a gh-authenticated repo"; exit 1; }

LOCATION="${LOCATION:-eastus}"
APP_NAME="github-oidc-${REPO##*/}"
STATE_RG="rg-lab-tfstate-eus-001"
CONTAINER="tfstate"

SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
# Deterministic, globally-unique-ish storage account name (3-24 chars, lowercase alnum)
SUFFIX=$(printf '%s' "$SUB_ID" | shasum -a 256 | cut -c1-10)
STATE_SA="sttflab${SUFFIX}"

echo "=== Phase 2 bootstrap ==="
echo "  repo         : $REPO"
echo "  subscription : $SUB_ID"
echo "  tenant       : $TENANT_ID"
echo "  state account: $STATE_SA"
echo

# ─── 1. App registration ─────────────────────────────────────────────────────
echo "[1/6] App registration '$APP_NAME'"
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv 2>/dev/null || true)
if [ -z "$APP_ID" ] || [ "$APP_ID" = "None" ]; then
    APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
    echo "  created appId=$APP_ID"
else
    echo "  exists  appId=$APP_ID"
fi

# ─── 2. Service principal ────────────────────────────────────────────────────
echo "[2/6] Service principal"
SP_OID=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" -o tsv 2>/dev/null || true)
if [ -z "$SP_OID" ] || [ "$SP_OID" = "None" ]; then
    SP_OID=$(az ad sp create --id "$APP_ID" --query id -o tsv)
    echo "  created objectId=$SP_OID"
    sleep 15   # Entra replication before role assignment
else
    echo "  exists  objectId=$SP_OID"
fi

# ─── 3. Federated credentials — no secret is ever created ────────────────────
# The subject claim binds the token to a specific repo AND ref. A token minted
# by any other repo, or by a different branch, will not be accepted.
echo "[3/6] Federated credentials"
add_fic() {
    local name="$1" subject="$2"
    if az ad app federated-credential list --id "$APP_ID" \
         --query "[?name=='$name'] | [0].name" -o tsv 2>/dev/null | grep -q "$name"; then
        echo "  exists  $name"
        return
    fi
    az ad app federated-credential create --id "$APP_ID" --parameters "{
        \"name\": \"$name\",
        \"issuer\": \"https://token.actions.githubusercontent.com\",
        \"subject\": \"$subject\",
        \"description\": \"GitHub Actions OIDC\",
        \"audiences\": [\"api://AzureADTokenExchange\"]
    }" >/dev/null
    echo "  created $name  ($subject)"
}
add_fic "github-main"         "repo:${REPO}:ref:refs/heads/main"
add_fic "github-pull-request" "repo:${REPO}:pull_request"

# ─── 4. Azure RBAC ───────────────────────────────────────────────────────────
# Contributor alone is NOT sufficient: the lab Terraform creates an AcrPull role
# assignment, and Contributor cannot write role assignments. "Role Based Access
# Control Administrator" grants exactly that and nothing more — preferred over
# User Access Administrator, which also grants elevate-access style powers.
echo "[4/6] Role assignments at subscription scope"
for ROLE in "Contributor" "Role Based Access Control Administrator"; do
    if az role assignment list --assignee "$SP_OID" --scope "/subscriptions/$SUB_ID" \
         --query "[?roleDefinitionName=='$ROLE'] | length(@)" -o tsv 2>/dev/null | grep -q '^[1-9]'; then
        echo "  exists  $ROLE"
    else
        az role assignment create --assignee-object-id "$SP_OID" \
            --assignee-principal-type ServicePrincipal \
            --role "$ROLE" --scope "/subscriptions/$SUB_ID" >/dev/null
        echo "  created $ROLE"
    fi
done

# ─── 5. Terraform state backend ──────────────────────────────────────────────
echo "[5/6] Remote state storage"
az group create --name "$STATE_RG" --location "$LOCATION" \
    --tags Environment=lab CostCenter=CC-PERSONAL Application=automation-lab \
           ManagedBy=terraform Owner=lab >/dev/null
echo "  rg      $STATE_RG"

if ! az storage account show --name "$STATE_SA" --resource-group "$STATE_RG" >/dev/null 2>&1; then
    az storage account create --name "$STATE_SA" --resource-group "$STATE_RG" \
        --location "$LOCATION" --sku Standard_LRS --kind StorageV2 \
        --min-tls-version TLS1_2 \
        --allow-blob-public-access false \
        --allow-shared-key-access false \
        --tags Environment=lab CostCenter=CC-PERSONAL Owner=lab \
               Application=automation-lab ManagedBy=bootstrap-script \
        >/dev/null
    echo "  created $STATE_SA (shared-key auth DISABLED — Entra only)"
else
    echo "  exists  $STATE_SA"
fi

# Tags are applied unconditionally: the first version of this script tagged the
# resource group but not the account, and the lab-baseline require-tags policy
# caught it. An untagged state account would be REJECTED once that control is
# promoted from Audit to Deny — the bootstrap would fail against the very
# governance it bootstraps.
az storage account update --name "$STATE_SA" --resource-group "$STATE_RG" \
    --set tags.Environment=lab tags.CostCenter=CC-PERSONAL tags.Owner=lab \
          tags.Application=automation-lab tags.ManagedBy=bootstrap-script \
    >/dev/null
echo "  tagged  $STATE_SA (5 mandatory tags)"

# Data-plane RBAC. This is the step everyone forgets: control-plane Contributor
# does NOT let you read or write blobs when shared-key auth is disabled.
echo "[6/6] Data-plane RBAC on the state account"
SA_ID=$(az storage account show --name "$STATE_SA" --resource-group "$STATE_RG" --query id -o tsv)
ME_OID=$(az ad signed-in-user show --query id -o tsv)
for PRINCIPAL in "$SP_OID:ServicePrincipal" "$ME_OID:User"; do
    OID="${PRINCIPAL%%:*}"; PTYPE="${PRINCIPAL##*:}"
    if az role assignment list --assignee "$OID" --scope "$SA_ID" \
         --query "[?roleDefinitionName=='Storage Blob Data Contributor'] | length(@)" -o tsv 2>/dev/null | grep -q '^[1-9]'; then
        echo "  exists  Storage Blob Data Contributor -> $PTYPE"
    else
        az role assignment create --assignee-object-id "$OID" \
            --assignee-principal-type "$PTYPE" \
            --role "Storage Blob Data Contributor" --scope "$SA_ID" >/dev/null
        echo "  created Storage Blob Data Contributor -> $PTYPE"
    fi
done

# Container needs the data-plane grant above, so create it last (with retry for
# RBAC propagation).
for i in $(seq 1 12); do
    if az storage container create --name "$CONTAINER" --account-name "$STATE_SA" \
         --auth-mode login >/dev/null 2>&1; then
        echo "  container $CONTAINER ready"; break
    fi
    [ "$i" -eq 12 ] && { echo "  ERROR: container create failed after RBAC propagation wait"; exit 1; }
    sleep 10
done

# ─── Summary ─────────────────────────────────────────────────────────────────
cat <<EOF

=== Done ===

Backend config (already written to backend.tf):
  resource_group_name  = "$STATE_RG"
  storage_account_name = "$STATE_SA"
  container_name       = "$CONTAINER"

Set these GitHub repository variables/secrets:
  gh variable set AZURE_CLIENT_ID       --body "$APP_ID"
  gh variable set AZURE_TENANT_ID       --body "$TENANT_ID"
  gh variable set AZURE_SUBSCRIPTION_ID --body "$SUB_ID"
  gh variable set TFSTATE_RG            --body "$STATE_RG"
  gh variable set TFSTATE_SA            --body "$STATE_SA"

These are IDs, not credentials — no secret exists for this identity. That is the
point of OIDC. Using 'variable' rather than 'secret' keeps them readable in logs
for debugging; nothing here is sensitive.

Migrate local state to the remote backend:
  cd lab/terraform/environments/lab && terraform init -migrate-state

To undo everything this created:
  az ad app delete --id $APP_ID
  az group delete --name $STATE_RG --yes
EOF
