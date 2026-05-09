#!/bin/bash
# =============================================================
#  Assignment 1 - Azure App Service Deployment
#  Auctionhouse API
#  Run: bash setup.sh
# =============================================================

set -e
export MSYS_NO_PATHCONV=1

# =============================================================
#  CONFIGURATION - Change as needed
# =============================================================
RESOURCE_GROUP="RG-Jakob-El-Saidi-0900c0-DotNetCloudDeveloper-VT-Mars-Goteborg"
LOCATION="swedencentral"
PLAN="plan-auctionhouse57"
APP_NAME="auctionhouse-api-dev57"
SQL_SERVER="auctionhouse-sql-dev57"
SQL_DB="AuctionHouseDB"
SQL_USER="sqladmin"
SQL_PASSWORD="BajsBajs123!"
STORAGE_ACCOUNT="stauctionhousedev57"
KV_NAME="kv-auctionhouse-dev57"
INSIGHTS_NAME="appi-auctionhouse57"
LAW_NAME="law-auctionhouse57"
SUBSCRIPTION_ID=$(az account show --query id --output tsv)

echo "============================================"
echo " Starting deployment..."
echo " App:     $APP_NAME"
echo " SQL:     $SQL_SERVER"
echo " Storage: $STORAGE_ACCOUNT"
echo " KV:      $KV_NAME"
echo "============================================"

# =============================================================
#  STEP 1 - APP SERVICE & SQL
# =============================================================

echo ">>> Creating App Service Plan (B1)..."
az appservice plan create --name $PLAN --resource-group $RESOURCE_GROUP --sku B1 --location $LOCATION

echo ">>> Creating App Service..."
az webapp create --name $APP_NAME --resource-group $RESOURCE_GROUP --plan $PLAN --runtime "dotnet:10"

echo ">>> Creating SQL Server..."
az sql server create --name $SQL_SERVER --resource-group $RESOURCE_GROUP --location $LOCATION --admin-user $SQL_USER --admin-password $SQL_PASSWORD

echo ">>> Waiting for SQL Server to be ready (30s)..."
sleep 30

echo ">>> Firewall - allow Azure services..."
az sql server firewall-rule create --name AllowAzureServices --resource-group $RESOURCE_GROUP --server $SQL_SERVER --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0

echo ">>> Firewall - allow your IP..."
MY_IP=$(curl -s https://api.ipify.org)
az sql server firewall-rule create --name AllowMyIP --resource-group $RESOURCE_GROUP --server $SQL_SERVER --start-ip-address $MY_IP --end-ip-address $MY_IP

echo ">>> Creating database (Basic)..."
az sql db create --name $SQL_DB --resource-group $RESOURCE_GROUP --server $SQL_SERVER --edition Basic

# =============================================================
#  STEP 2 - APPLICATION INSIGHTS
# =============================================================

echo ">>> Creating Log Analytics Workspace (PerGB2018)..."
az monitor log-analytics workspace create --name $LAW_NAME --resource-group $RESOURCE_GROUP --location $LOCATION --sku PerGB2018

echo ">>> Creating Application Insights..."
az monitor app-insights component create --app $INSIGHTS_NAME --location $LOCATION --resource-group $RESOURCE_GROUP --workspace $LAW_NAME

echo ">>> Waiting for Application Insights to be ready (15s)..."
sleep 15

CONN_STR=$(az monitor app-insights component show --app $INSIGHTS_NAME --resource-group $RESOURCE_GROUP --query connectionString --output tsv)

echo ">>> Connecting Application Insights to App Service..."
az webapp config appsettings set --name $APP_NAME --resource-group $RESOURCE_GROUP --settings APPLICATIONINSIGHTS_CONNECTION_STRING="$CONN_STR"

# =============================================================
#  STEP 3 - SECURITY
# =============================================================

echo ">>> IP restriction - your IP: $MY_IP"
az webapp config access-restriction add --name $APP_NAME --resource-group $RESOURCE_GROUP --rule-name AllowMyIP --action Allow --ip-address "${MY_IP}/32" --priority 100

echo ">>> Enabling HTTPS-only..."
az webapp update --name $APP_NAME --resource-group $RESOURCE_GROUP --https-only true

echo ">>> Setting minimum TLS version to 1.2..."
az webapp config set --name $APP_NAME --resource-group $RESOURCE_GROUP --min-tls-version 1.2

# =============================================================
#  STEP 4 - STORAGE ACCOUNT
# =============================================================

echo ">>> Creating Storage Account..."
az storage account create --name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP --location $LOCATION --sku Standard_LRS --kind StorageV2 --allow-shared-key-access true

STORAGE_KEY=$(az storage account keys list --account-name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP --query "[0].value" --output tsv)

echo ">>> Creating containers..."
az storage container create --name backups37 --account-name $STORAGE_ACCOUNT --account-key $STORAGE_KEY --public-access off
az storage container create --name logs --account-name $STORAGE_ACCOUNT --account-key $STORAGE_KEY --public-access off
az storage container create --name staticfiles --account-name $STORAGE_ACCOUNT --account-key $STORAGE_KEY --public-access off

echo ">>> Generating SAS token..."
SAS=$(az storage container generate-sas --account-name $STORAGE_ACCOUNT --account-key $STORAGE_KEY --name backups --permissions rwdl --expiry 2099-12-31 --output tsv)

BACKUP_URL="https://${STORAGE_ACCOUNT}.blob.core.windows.net/backups?${SAS}"

echo ">>> Creating initial backup..."
az webapp config backup create --resource-group $RESOURCE_GROUP --webapp-name $APP_NAME --container-url "$BACKUP_URL" --backup-name "initial-backup"

echo ">>> Waiting for backup to initialize (30s)..."
sleep 30

echo ">>> Scheduling daily backup..."
az webapp config backup update --resource-group $RESOURCE_GROUP --webapp-name $APP_NAME --container-url "$BACKUP_URL" --backup-name "scheduled-backup" --frequency 1d --retention 30 --retain-one true

echo ">>> Storage Account $STORAGE_ACCOUNT used for:"
echo "    - Daily backups (container: backups)"
echo "    - Static files (container: staticfiles)"
echo "    - Log files (container: logs)"

# =============================================================
#  STEP 5 - KEY VAULT & MANAGED IDENTITY
# =============================================================

echo ">>> Creating Key Vault..."
az keyvault create --name $KV_NAME --resource-group $RESOURCE_GROUP --location $LOCATION --sku standard --enable-rbac-authorization true

echo ">>> Assigning Key Vault Secrets Officer role to yourself..."
USER_EMAIL=$(az account show --query user.name --output tsv)
az role assignment create --assignee $USER_EMAIL --role "Key Vault Secrets Officer" --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KV_NAME

echo ">>> Waiting for role to propagate (15s)..."
sleep 15

echo ">>> Storing connection string as secret..."
az keyvault secret set --vault-name $KV_NAME --name DefaultConnection --value "Server=tcp:${SQL_SERVER}.database.windows.net,1433;Initial Catalog=${SQL_DB};User ID=${SQL_USER};Password=${SQL_PASSWORD};Encrypt=True;TrustServerCertificate=False"

echo ">>> Enabling Managed Identity on App Service..."
az webapp identity assign --name $APP_NAME --resource-group $RESOURCE_GROUP

echo ">>> Waiting for Managed Identity to propagate (120s)..."
sleep 120

PRINCIPAL_ID=$(az webapp identity show --name $APP_NAME --resource-group $RESOURCE_GROUP --query principalId --output tsv)

echo ">>> Assigning Key Vault Secrets User role to App Service..."
USER_OBJECT_ID=$(az ad signed-in-user show --query id --output tsv)
az role assignment create --assignee-object-id $USER_OBJECT_ID --assignee-principal-type User --role "Key Vault Secrets Officer" --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KV_NAME

SECRET_URI=$(az keyvault secret show --vault-name $KV_NAME --name DefaultConnection --query id --output tsv)

echo ">>> Setting Key Vault reference in App Service..."
az webapp config appsettings set --name $APP_NAME --resource-group $RESOURCE_GROUP --settings "DefaultConnection=@Microsoft.KeyVault(SecretUri=${SECRET_URI})"

# =============================================================
#  GITHUB ACTIONS SERVICE PRINCIPAL
# =============================================================

echo ">>> Creating service principal for GitHub Actions..."
SP_OUTPUT=$(az ad sp create-for-rbac --name "github-actions-auctionhouse" --role contributor --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP --sdk-auth)

# =============================================================
#  DONE!
# =============================================================

echo ""
echo "============================================"
echo " DEPLOYMENT COMPLETE!"
echo "============================================"
echo ""
echo "  App Service URL: https://$APP_NAME.azurewebsites.net"
echo ""
echo "============================================"
echo " GITHUB ACTIONS - Service Principal JSON:"
echo " Copy the block below and add as GitHub Secret (AZURE_CREDENTIALS):"
echo "============================================"
echo "$SP_OUTPUT"
echo "============================================"
echo ""
echo "  MANUAL STEPS REMAINING:"
echo ""
echo "  1. GitHub Actions:"
echo "     - Copy the JSON above -> GitHub -> Settings -> Secrets -> Actions"
echo "     - Create secret: AZURE_CREDENTIALS"
echo "     - Ensure .github/workflows/azure-deploy.yml exists in repo root"
echo ""
echo "  2. Code changes in the project:"
echo "     - dotnet add package Azure.Monitor.OpenTelemetry.AspNetCore"
echo "     - Add: builder.Services.AddOpenTelemetry().UseAzureMonitor();"
echo "     - Change GetConnectionString to builder.Configuration"
echo ""
echo "  3. Run EF migrations against Azure SQL after deployment"
echo ""
echo "  4. Clean up resources when done (keep resource group):"
echo "     az webapp delete --name $APP_NAME --resource-group $RESOURCE_GROUP"
echo "     az appservice plan delete --name $PLAN --resource-group $RESOURCE_GROUP --yes"
echo "     az sql server delete --name $SQL_SERVER --resource-group $RESOURCE_GROUP --yes"
echo "     az storage account delete --name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP --yes"
echo "     az keyvault delete --name $KV_NAME --resource-group $RESOURCE_GROUP"
echo "     az monitor app-insights component delete --app $INSIGHTS_NAME --resource-group $RESOURCE_GROUP"
echo "     az monitor log-analytics workspace delete --workspace-name $LAW_NAME --resource-group $RESOURCE_GROUP --yes"
echo ""
echo "============================================"