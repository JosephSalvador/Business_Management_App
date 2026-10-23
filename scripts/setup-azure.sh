#!/usr/bin/env bash
# ==============================================================================
# BusinessOS — One-Click Azure Provisioning Script (GitHub Student Pack)
# ==============================================================================
# This script provisions:
# 1. Resource Group: rg-businessos
# 2. Azure Container Apps Environment: cae-businessos
# 3. Azure PostgreSQL Flexible Server (Burstable B1ms - Free tier for 12 months)
# 4. Azure Container App: jolinx-api (running 24/7 with min-replicas 1)
# 5. Service Principal for automated GitHub Actions deployments
# ==============================================================================

set -euo pipefail

# Configuration
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-jolinx-prod}"
LOCATION="${LOCATION:-centralindia}"
CONTAINERAPPS_ENV="${CONTAINERAPPS_ENV:-cae-jolinx-prod}"
APP_NAME="${APP_NAME:-jolinx-api}"
DB_NAME="${DB_NAME:-businessos}"
DB_ADMIN_USER="${DB_ADMIN_USER:-dbadmin}"

# Generate secure random passwords/keys
DB_ADMIN_PASSWORD="${DB_ADMIN_PASSWORD:-$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)!Aa1}"
JWT_SECRET="${JWT_SECRET:-$(openssl rand -base64 32)}"
TFA_KEY="${TFA_KEY:-$(openssl rand -base64 32)}"

# Generate unique DB server name (alphanumeric and lowercase only)
UNIQUE_SUFFIX=$(openssl rand -hex 4)
DB_SERVER_NAME="${DB_SERVER_NAME:-businessos-db-${UNIQUE_SUFFIX}}"

echo "=========================================================="
echo " Starting Jolinx BusinessOS Azure Provisioning..."
echo " Resource Group: ${RESOURCE_GROUP}"
echo " Location:       ${LOCATION}"
echo " Database:       ${DB_SERVER_NAME}.postgres.database.azure.com"
echo "=========================================================="

# Check login status
echo "Checking Azure authentication..."
az account show > /dev/null 2>&1 || {
  echo "Error: You are not logged in to Azure."
  echo "Please run 'az login' first or run this script inside Azure Cloud Shell (https://portal.azure.com)."
  exit 1
}

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "Using Azure Subscription: ${SUBSCRIPTION_ID}"

# 1. Create Resource Group
echo "Creating Resource Group '${RESOURCE_GROUP}' in '${LOCATION}'..."
az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}" --output table

# 2. Install Container Apps CLI extension if not present
echo "Ensuring Azure Container Apps extension is installed..."
az extension add --name containerapp --upgrade --yes > /dev/null 2>&1 || true

# 3. Create Container Apps Environment
echo "Creating Container Apps Environment '${CONTAINERAPPS_ENV}'..."
az containerapp env create \
  --name "${CONTAINERAPPS_ENV}" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --output table

# 4. Create Azure Database for PostgreSQL (Burstable B1ms - Free for Students)
echo "Creating PostgreSQL Flexible Server '${DB_SERVER_NAME}' (Standard_B1ms, 32GB)..."
az postgres flexible-server create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${DB_SERVER_NAME}" \
  --location "${LOCATION}" \
  --admin-user "${DB_ADMIN_USER}" \
  --admin-password "${DB_ADMIN_PASSWORD}" \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --storage-size 32 \
  --database-name "${DB_NAME}" \
  --yes \
  --output table

echo "Allowing Azure Services access through PostgreSQL firewall..."
az postgres flexible-server firewall-rule create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${DB_SERVER_NAME}" \
  --rule-name AllowAllAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0 \
  --output table

# Construct Connection String for Npgsql (.NET)
CONNECTION_STRING="Host=${DB_SERVER_NAME}.postgres.database.azure.com;Port=5432;Database=${DB_NAME};Username=${DB_ADMIN_USER};Password=${DB_ADMIN_PASSWORD};SSL Mode=Require;Trust Server Certificate=true;"

# 5. Create the Initial Container App
echo "Deploying Container App '${APP_NAME}'..."
az containerapp create \
  --name "${APP_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --environment "${CONTAINERAPPS_ENV}" \
  --image mcr.microsoft.com/dotnet/samples:aspnetapp \
  --target-port 8080 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 2 \
  --env-vars \
    "PORT=8080" \
    "ASPNETCORE_ENVIRONMENT=Production" \
    "DOTNET_ENVIRONMENT=Production" \
    "ConnectionStrings__Default=${CONNECTION_STRING}" \
    "Jwt__Secret=${JWT_SECRET}" \
    "Security__TwoFactorEncryptionKey=${TFA_KEY}" \
  --output table

# Get Public FQDN
APP_URL=$(az containerapp show --name "${APP_NAME}" --resource-group "${RESOURCE_GROUP}" --query properties.configuration.ingress.fqdn -o tsv)

# 6. Generate GitHub Actions Deployment Credentials
echo "Creating Service Principal for GitHub Actions CI/CD..."
SP_JSON=$(az ad sp create-for-rbac \
  --name "sp-github-actions-${APP_NAME}" \
  --role contributor \
  --scopes "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}" \
  --json-auth 2>/dev/null || true)

echo ""
echo "=========================================================="
echo " PROVISIONING COMPLETE!"
echo "=========================================================="
echo "Container App URL:  https://${APP_URL}"
echo "Database Host:      ${DB_SERVER_NAME}.postgres.database.azure.com"
echo "Database User:      ${DB_ADMIN_USER}"
echo "Database Password:  ${DB_ADMIN_PASSWORD}"
echo "Database Name:      ${DB_NAME}"
echo ""
echo "=========================================================="
echo " GITHUB ACTIONS SECRET (AZURE_CREDENTIALS)"
echo " Add the following JSON in GitHub -> Settings -> Secrets -> Actions:"
echo " Secret Name: AZURE_CREDENTIALS"
echo "----------------------------------------------------------"
if [ -n "${SP_JSON}" ]; then
  echo "${SP_JSON}"
else
  echo "Could not auto-generate Service Principal JSON. You can generate it anytime using:"
  echo "az ad sp create-for-rbac --name \"sp-${APP_NAME}\" --role contributor --scopes \"/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}\" --json-auth"
fi
echo "=========================================================="
