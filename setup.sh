#!/bin/bash
# =============================================================
#  Inlämningsuppgift 1 – Azure App Service Deployment
#  Auctionhouse API
#  Körning: bash setup.sh
# =============================================================

set -e

# =============================================================
#  KONFIGURATION – Ändra vid behov
# =============================================================
RESOURCE_GROUP="RG-Jakob-El-Saidi-0900c0-DotNetCloudDeveloper-VT-Mars-Goteborg"
LOCATION="swedencentral"
PLAN="plan-auctionhouse"
APP_NAME="auctionhouse-api-dev"
SQL_SERVER="auctionhouse-sql-dev93"
SQL_DB="AuctionHouseDB"
SQL_USER="sqladmin"
SQL_PASSWORD="BajsBajs123!"
STORAGE_ACCOUNT="stauctionhousedev"
KV_NAME="kv-auctionhouse-dev93"
INSIGHTS_NAME="appi-auctionhouse"
LAW_NAME="law-auctionhouse"
SUBSCRIPTION_ID="457c50ad-2cb0-4bed-9fea-fbdf6eed15bf"

echo "============================================"
echo " Startar deployment..."
echo " App:     $APP_NAME"
echo " SQL:     $SQL_SERVER"
echo " Storage: $STORAGE_ACCOUNT"
echo " KV:      $KV_NAME"
echo "============================================"

# =============================================================
#  STEG 1 – APP SERVICE & SQL
# =============================================================

echo ">>> Skapar App Service Plan (B1)..."
az appservice plan create \
  --name $PLAN \
  --resource-group $RESOURCE_GROUP \
  --sku B1 \
  --location $LOCATION

echo ">>> Skapar App Service..."
az webapp create \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --plan $PLAN \
  --runtime "dotnet:10"

echo ">>> Skapar SQL Server..."
az sql server create \
  --name $SQL_SERVER \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --admin-user $SQL_USER \
  --admin-password $SQL_PASSWORD

echo ">>> Brandväggsregel – tillåt Azure-tjänster..."
az sql server firewall-rule create \
  --name AllowAzureServices \
  --resource-group $RESOURCE_GROUP \
  --server $SQL_SERVER \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0

echo ">>> Brandväggsregel – tillåt din IP..."
MY_IP=$(curl -s https://api.ipify.org)
az sql server firewall-rule create \
  --name AllowMyIP \
  --resource-group $RESOURCE_GROUP \
  --server $SQL_SERVER \
  --start-ip-address $MY_IP \
  --end-ip-address $MY_IP

echo ">>> Skapar databas (Basic)..."
az sql db create \
  --name $SQL_DB \
  --resource-group $RESOURCE_GROUP \
  --server $SQL_SERVER \
  --edition Basic

# =============================================================
#  STEG 2 – APPLICATION INSIGHTS
# =============================================================

echo ">>> Skapar Log Analytics Workspace (PerGB2018)..."
az monitor log-analytics workspace create \
  --name $LAW_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku PerGB2018

echo ">>> Skapar Application Insights..."
az monitor app-insights component create \
  --app $INSIGHTS_NAME \
  --location $LOCATION \
  --resource-group $RESOURCE_GROUP \
  --workspace $LAW_NAME

CONN_STR=$(az monitor app-insights component show \
  --app $INSIGHTS_NAME \
  --resource-group $RESOURCE_GROUP \
  --query connectionString --output tsv)

echo ">>> Kopplar Application Insights till App Service..."
az webapp config appsettings set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings APPLICATIONINSIGHTS_CONNECTION_STRING="$CONN_STR"

# =============================================================
#  STEG 3 – SÄKERHET
# =============================================================

echo ">>> IP-restriktion – hämtar din IP..."
MY_IP=$(curl -s https://api.ipify.org)
echo "    Din IP: $MY_IP"

az webapp config access-restriction add \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --rule-name AllowMyIP \
  --action Allow \
  --ip-address "${MY_IP}/32" \
  --priority 100

echo ">>> Aktiverar HTTPS-only..."
az webapp update \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --https-only true

echo ">>> Sätter lägsta TLS-version till 1.2..."
az webapp config set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --min-tls-version 1.2

echo ">>> Skapar Storage Account för backuper..."
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2

STORAGE_KEY=$(az storage account keys list \
  --account-name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --query "[0].value" --output tsv)

echo ">>> Skapar backup-container..."
az storage container create \
  --name backups \
  --account-name $STORAGE_ACCOUNT \
  --account-key $STORAGE_KEY \
  --public-access off

echo ">>> Genererar SAS-token..."
SAS=$(az storage container generate-sas \
  --account-name $STORAGE_ACCOUNT \
  --name backups \
  --permissions rwdl \
  --expiry 2099-12-31 \
  --output tsv)

BACKUP_URL="https://${STORAGE_ACCOUNT}.blob.core.windows.net/backups?${SAS}"

echo ">>> Skapar en initial backup..."
az webapp config backup create \
  --resource-group $RESOURCE_GROUP \
  --webapp-name $APP_NAME \
  --container-url "$BACKUP_URL"

echo ">>> Schemalägger daglig backup..."
az webapp config backup update \
  --resource-group $RESOURCE_GROUP \
  --webapp-name $APP_NAME \
  --container-url "$BACKUP_URL" \
  --frequency 1d \
  --retention 30 \
  --retain-one true

# =============================================================
#  STEG 4 – STORAGE ACCOUNT
# =============================================================

echo ">>> Storage Account $STORAGE_ACCOUNT används för:"
echo "    - Dagliga backuper (container: backups)"
echo "    - Kan utökas med containrar för statiska filer/loggar"

# =============================================================
#  STEG 5 – KEY VAULT & MANAGED IDENTITY
# =============================================================

echo ">>> Skapar Key Vault..."
az keyvault create \
  --name $KV_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku standard

echo ""
echo "    MANUELLT STEG – Roller måste sättas via portalen pga skolmiljöns RBAC-begränsningar:"
echo "    1. Gå till Key Vault -> Access control (IAM)"
echo "    2. Lägg till 'Key Vault Secrets Officer' för dig själv"
echo "    3. Skapa hemligheten 'DefaultConnection' under Secrets"
echo "    4. Lägg till 'Key Vault Secrets User' för App Services Managed Identity"
echo "    5. Sätt Key Vault-referensen @Microsoft.KeyVault(SecretUri=...) i App Service -> Environment variables"
echo ""

echo ">>> Aktiverar Managed Identity på App Service..."
az webapp identity assign \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP

PRINCIPAL_ID=$(az webapp identity show \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query principalId --output tsv)

echo "    App Service Managed Identity Principal ID: $PRINCIPAL_ID"
echo "    Använd detta ID när du tilldelar Key Vault Secrets User-rollen i portalen."

# =============================================================
#  KLART
# =============================================================

echo ""
echo "============================================"
echo " DEPLOYMENT KLAR!"
echo "============================================"
echo ""
echo "  App Service URL: https://${APP_NAME}.azurewebsites.net"
echo ""
echo "  MANUELLA STEG SOM ÅTERSTÅR:"
echo ""
echo "  1. Key Vault (portalen):"
echo "     - Ge dig själv rollen 'Key Vault Secrets Officer'"
echo "     - Skapa hemligheten 'DefaultConnection'"
echo "     - Ge Managed Identity ($PRINCIPAL_ID) rollen 'Key Vault Secrets User'"
echo "     - Sätt @Microsoft.KeyVault(SecretUri=...) som DefaultConnection i App Service"
echo ""
echo "  2. GitHub Actions:"
echo "     - Använd befintlig AZURE_CREDENTIALS secret"
echo "     - Se till att .github/workflows/azure-deploy.yml finns i repo-roten"
echo ""
echo "  3. Kodändringar i projektet:"
echo "     - dotnet add package Azure.Monitor.OpenTelemetry.AspNetCore"
echo "     - Lägg till: builder.Services.AddOpenTelemetry().UseAzureMonitor();"
echo "     - Ändra GetConnectionString(\"DefaultConnection\") till builder.Configuration[\"DefaultConnection\"]"
echo ""
echo "  4. Kör EF-migreringar mot Azure SQL efter deployment"
echo ""
echo "  5. Rensa resurser när klart (behåll resursgruppen):"
echo "     az webapp delete --name $APP_NAME --resource-group $RESOURCE_GROUP"
echo "     az appservice plan delete --name $PLAN --resource-group $RESOURCE_GROUP --yes"
echo "     az sql server delete --name $SQL_SERVER --resource-group $RESOURCE_GROUP --yes"
echo "     az storage account delete --name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP --yes"
echo "     az keyvault delete --name $KV_NAME --resource-group $RESOURCE_GROUP"
echo "     az monitor app-insights component delete --app $INSIGHTS_NAME --resource-group $RESOURCE_GROUP"
echo "     az monitor log-analytics workspace delete --workspace-name $LAW_NAME --resource-group $RESOURCE_GROUP --yes"
echo ""
echo "============================================"