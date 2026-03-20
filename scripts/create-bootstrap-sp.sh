#!/usr/bin/env bash
# =============================================================================
# create-bootstrap-sp.sh
#
# Creates the temporary "StrivoApp-bootstrap" service principal used by the
# setup-azure-oidc.yml workflow to bootstrap the permanent OIDC identity.
#
# Usage:
#   ./scripts/create-bootstrap-sp.sh <subscription-id> [resource-group]
#
# The script prints the exact values you need to add as GitHub repository
# secrets.  Copy each value carefully — the client secret VALUE is shown
# once only; it is NOT the same as the Secret ID shown in the Azure Portal.
#
# Prerequisites:
#   - Azure CLI logged in as a user with:
#       * "Application Administrator" (or "Global Administrator") in Entra ID
#       * "Owner" (or "Contributor" + "User Access Administrator") on the
#         target resource group
#   - jq installed (sudo apt install jq / brew install jq)
# =============================================================================
set -euo pipefail

SUBSCRIPTION_ID="${1:-}"
RG="${2:-rg-day1-bear}"
SP_NAME="StrivoApp-bootstrap"

if [[ -z "$SUBSCRIPTION_ID" ]]; then
  echo "Usage: $0 <subscription-id> [resource-group]" >&2
  echo "Example: $0 00000000-0000-0000-0000-000000000000 rg-day1-bear" >&2
  exit 1
fi

echo "=== Creating service principal '$SP_NAME' ==="
echo "Subscription : $SUBSCRIPTION_ID"
echo "Resource group: $RG"
echo ""

# Create the SP with Contributor role on the resource group.
# The JSON output contains:  appId, password (secret VALUE), tenant
SP_JSON=$(az ad sp create-for-rbac \
  --name "$SP_NAME" \
  --role "Contributor" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG" \
  --output json)

APP_ID=$(echo "$SP_JSON" | jq -r '.appId')
# IMPORTANT: .password is the client secret VALUE — NOT the Secret ID shown
# in the Azure Portal "Certificates & secrets" tab.
CLIENT_SECRET_VALUE=$(echo "$SP_JSON" | jq -r '.password')
TENANT_ID=$(echo "$SP_JSON" | jq -r '.tenant')

# Grant User Access Administrator so the bootstrap workflow can assign the
# Contributor role to the new DemoIaCApp service principal.
BOOTSTRAP_OBJ_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)
az role assignment create \
  --assignee "$BOOTSTRAP_OBJ_ID" \
  --role "User Access Administrator" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG" \
  --output none
echo "Assigned 'User Access Administrator' on $RG."

# The "Application Administrator" Entra ID directory role must be assigned
# manually in the Azure Portal because the Azure CLI cannot assign directory
# roles without additional permissions.
echo ""
echo "⚠️  MANUAL STEP REQUIRED ⚠️"
echo "Assign the 'Application Administrator' directory role to '$SP_NAME' in"
echo "the Azure Portal:"
echo "  Entra ID → Roles and administrators → Application Administrator"
echo "  → Add assignments → search for '$SP_NAME'"
echo ""
echo "Press Enter once you have assigned the role, or Ctrl-C to abort."
read -r

echo ""
echo "============================================================"
echo " GitHub Repository Secrets"
echo " Settings → Secrets and variables → Actions"
echo " → New repository secret"
echo "============================================================"
echo ""
echo "Secret name              | Value"
echo "-------------------------|-----------------------------------"
printf "%-25s| %s\n" "AZURE_ADMIN_CLIENT_ID"     "$APP_ID"
printf "%-25s| %s\n" "AZURE_ADMIN_CLIENT_SECRET" "$CLIENT_SECRET_VALUE"
printf "%-25s| %s\n" "AZURE_TENANT_ID"           "$TENANT_ID"
printf "%-25s| %s\n" "AZURE_SUBSCRIPTION_ID"     "$SUBSCRIPTION_ID"
echo ""
echo "⚠️  IMPORTANT: Copy AZURE_ADMIN_CLIENT_SECRET from the 'Value' column"
echo "   above.  Do NOT use the 'Secret ID' shown in the Azure Portal — that"
echo "   is a different UUID and will cause an AADSTS7000215 login error."
echo ""
echo "After adding all four secrets, run the 'Bootstrap Azure Identity'"
echo "workflow (Actions → Bootstrap Azure Identity → Run workflow → confirm=yes)."
echo "============================================================"
