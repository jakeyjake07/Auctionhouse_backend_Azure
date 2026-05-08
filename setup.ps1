# =============================================================
#  Inlamningsuppgift 1 – Azure App Service Deployment
#  Auctionhouse API
#  Korning: .\setup.ps1
# =============================================================

$ErrorActionPreference = "Stop"

# =============================================================
#  KONFIGURATION – Andra vid behov
# =============================================================
$RESOURCE_GROUP = "RG-Jakob-El-Saidi-0900c0-DotNetCloudDeveloper-VT-Mars-Goteborg"
$LOCATION = "swedencentral"
$PLAN = "plan-auctionhouse"
$APP_NAME = "auctionhouse-api-dev"
$SQL_SERVER = "auctionhouse-sql-dev997"
$SQL_DB = "AuctionHouseDB"
$SQL_USER = "sqladmin"
$SQL_PASSWORD = "BajsBajs123!"
$STORAGE_ACCOUNT = "stauctionhousedev"
$KV_NAME = "kv-auctionhouse-dev997"
$INSIGHTS_NAME = "appi-auctionhouse"
$LAW_NAME = "law-auctionhouse"
$SUBSCRIPTION_ID = "457c50ad-2cb0-4bed-9fea-fbdf6eed15bf"

Write-Host "============================================"
Write-Host " Startar deployment..."
Write-Host " App:     $APP_NAME"
Write-Host " SQL:     $SQL_SERVER"
Write-Host " Storage: $STORAGE_ACCOUNT"
Write-Host " KV:      $KV_NAME"
Write-Host "============================================"

# =============================================================
#  STEG 1 – APP SERVICE & SQL
# =============================================================

Write-Host ">>> Skapar App Service Plan (B1)..."
az appservice plan create `
  --name $PLAN `
  --resource-group $RESOURCE_GROUP `
  --sku B1 `
  --location $LOCATION

Write-Host ">>> Skapar App Service..."
az webapp create `
  --name $APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --plan $PLAN `
  --runtime "dotnet:10"

Write-Host ">>> Skapar SQL Server..."
az sql server create `
  --name $SQL_SERVER `
  --resource-group $RESOURCE_GROUP `
  --location $LOCATION `
  --admin-user $SQL_USER `
  --admin-password $SQL_PASSWORD

Write-Host ">>> Brandvagg – tillat Azure-tjanster..."
az sql server firewall-rule create `
  --name AllowAzureServices `
  --resource-group $RESOURCE_GROUP `
  --server $SQL_SERVER `
  --start-ip-address 0.0.0.0 `
  --end-ip-address 0.0.0.0

Write-Host ">>> Brandvagg – tillat din IP..."
$MY_IP = (Invoke-WebRequest -Uri https://api.ipify.org -UseBasicParsing).Content.Trim()
az sql server firewall-rule create `
  --name AllowMyIP `
  --resource-group $RESOURCE_GROUP `
  --server $SQL_SERVER `
  --start-ip-address $MY_IP `
  --end-ip-address $MY_IP

Write-Host ">>> Skapar databas (Basic)..."
az sql db create `
  --name $SQL_DB `
  --resource-group $RESOURCE_GROUP `
  --server $SQL_SERVER `
  --edition Basic

# =============================================================
#  STEG 2 – APPLICATION INSIGHTS
# =============================================================

Write-Host ">>> Skapar Log Analytics Workspace (PerGB2018)..."
az monitor log-analytics workspace create `
  --name $LAW_NAME `
  --resource-group $RESOURCE_GROUP `
  --location $LOCATION `
  --sku PerGB2018

Write-Host ">>> Skapar Application Insights..."
az monitor app-insights component create `
  --app $INSIGHTS_NAME `
  --location $LOCATION `
  --resource-group $RESOURCE_GROUP `
  --workspace $LAW_NAME

$CONN_STR = az monitor app-insights component show `
  --app $INSIGHTS_NAME `
  --resource-group $RESOURCE_GROUP `
  --query connectionString --output tsv

Write-Host ">>> Kopplar Application Insights till App Service..."
az webapp config appsettings set `
  --name $APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --settings APPLICATIONINSIGHTS_CONNECTION_STRING="$CONN_STR"

# =============================================================
#  STEG 3 – SÄKERHET
# =============================================================

Write-Host ">>> IP-restriktion – din IP: $MY_IP"
az webapp config access-restriction add `
  --name $APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --rule-name AllowMyIP `
  --action Allow `
  --ip-address "${MY_IP}/32" `
  --priority 100

Write-Host ">>> Aktiverar HTTPS-only..."
az webapp update `
  --name $APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --https-only true

Write-Host ">>> Satter lagsta TLS-version till 1.2..."
az webapp config set `
  --name $APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --min-tls-version 1.2

Write-Host ">>> Skapar Storage Account for backuper..."
az storage account create `
  --name $STORAGE_ACCOUNT `
  --resource-group $RESOURCE_GROUP `
  --location $LOCATION `
  --sku Standard_LRS `
  --kind StorageV2

$STORAGE_KEY = az storage account keys list `
  --account-name $STORAGE_ACCOUNT `
  --resource-group $RESOURCE_GROUP `
  --query "[0].value" --output tsv

Write-Host ">>> Skapar backup-container..."
az storage container create `
  --name backups `
  --account-name $STORAGE_ACCOUNT `
  --account-key $STORAGE_KEY `
  --public-access off

Write-Host ">>> Genererar SAS-token..."
$SAS = az storage container generate-sas `
  --account-name $STORAGE_ACCOUNT `
  --name backups `
  --permissions rwdl `
  --expiry 2099-12-31 `
  --output tsv

$BACKUP_URL = "https://${STORAGE_ACCOUNT}.blob.core.windows.net/backups?${SAS}"

Write-Host ">>> Skapar en initial backup..."
az webapp config backup create `
  --resource-group $RESOURCE_GROUP `
  --webapp-name $APP_NAME `
  --container-url $BACKUP_URL

Write-Host ">>> Schemalagger daglig backup..."
az webapp config backup update `
  --resource-group $RESOURCE_GROUP `
  --webapp-name $APP_NAME `
  --container-url $BACKUP_URL `
  --frequency 1d `
  --retention 30 `
  --retain-one true

# =============================================================
#  STEG 4 – STORAGE ACCOUNT
# =============================================================

Write-Host ">>> Storage Account $STORAGE_ACCOUNT anvands for:"
Write-Host "    - Dagliga backuper (container: backups)"
Write-Host "    - Kan utokas med containrar for statiska filer/loggar"

# =============================================================
#  GITHUB ACTIONS SERVICE PRINCIPAL
# =============================================================

Write-Host ">>> Skapar service principal for GitHub Actions..."
try {
  $SP_OUTPUT = az ad sp create-for-rbac `
    --name "github-actions-auctionhouse" `
    --role contributor `
    --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP `
    --sdk-auth 2>&1

  Write-Host ""
  Write-Host "============================================"
  Write-Host " Service principal skapad!"
  Write-Host " Kopiera JSON-blocket nedan."
  Write-Host " Ga till GitHub -> Settings -> Secrets -> Actions"
  Write-Host " Skapa secret: AZURE_CREDENTIALS"
  Write-Host " Klistra in hela JSON-blocket som varde."
  Write-Host "============================================"
  Write-Host $SP_OUTPUT
  Write-Host "============================================"
}
catch {
  Write-Host "Kunde inte skapa service principal automatiskt."
  Write-Host "Gor detta manuellt via portalen (Entra ID -> App registrations)."
}

# =============================================================
#  STEG 5 – KEY VAULT & MANAGED IDENTITY
# =============================================================

Write-Host ">>> Skapar Key Vault..."
az keyvault create `
  --name $KV_NAME `
  --resource-group $RESOURCE_GROUP `
  --location $LOCATION `
  --sku standard

Write-Host ">>> Ger dig sjalv Key Vault Secrets Officer-roll..."
$USER_EMAIL = az account show --query user.name --output tsv

az role assignment create `
  --assignee $USER_EMAIL `
  --role "Key Vault Secrets Officer" `
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KV_NAME

Write-Host ">>> Vantar pa att rollen ska propagera (15s)..."
Start-Sleep -Seconds 15

Write-Host ">>> Lagrar connectionstring som hemlighet..."
az keyvault secret set `
  --vault-name $KV_NAME `
  --name DefaultConnection `
  --value "Server=tcp:${SQL_SERVER}.database.windows.net,1433;Initial Catalog=${SQL_DB};User ID=${SQL_USER};Password=${SQL_PASSWORD};Encrypt=True;TrustServerCertificate=False"

Write-Host ">>> Aktiverar Managed Identity pa App Service..."
az webapp identity assign `
  --name $APP_NAME `
  --resource-group $RESOURCE_GROUP

Write-Host ">>> Vantar pa att Managed Identity ska propagera (20s)..."
Start-Sleep -Seconds 20

$PRINCIPAL_ID = az webapp identity show `
  --name $APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --query principalId --output tsv

Write-Host ">>> Ger App Service Key Vault Secrets User-roll..."
az role assignment create `
  --assignee-object-id $PRINCIPAL_ID `
  --assignee-principal-type ServicePrincipal `
  --role "Key Vault Secrets User" `
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KV_NAME

$SECRET_URI = az keyvault secret show `
  --vault-name $KV_NAME `
  --name DefaultConnection `
  --query id --output tsv

Write-Host ">>> Satter Key Vault-referens i App Service..."
az webapp config appsettings set `
  --name $APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --settings "DefaultConnection=@Microsoft.KeyVault(SecretUri=${SECRET_URI})"

# =============================================================
#  KLART!
# =============================================================

Write-Host ""
Write-Host "============================================"
Write-Host " DEPLOYMENT KLAR!"
Write-Host "============================================"
Write-Host ""
Write-Host "  App Service URL: https://$APP_NAME.azurewebsites.net"
Write-Host ""
Write-Host "  MANUELLA STEG SOM ATERSTAR:"
Write-Host ""
Write-Host "  1. GitHub Actions:"
Write-Host "     - Lagg JSON-utdatan ovan som AZURE_CREDENTIALS i GitHub Secrets"
Write-Host "     - Se till att .github/workflows/azure-deploy.yml finns i repo-roten"
Write-Host ""
Write-Host "  2. Kodandringar i projektet:"
Write-Host "     - dotnet add package Azure.Monitor.OpenTelemetry.AspNetCore"
Write-Host "     - Lagg till: builder.Services.AddOpenTelemetry().UseAzureMonitor();"
Write-Host "     - Andra GetConnectionString('DefaultConnection') till builder.Configuration['DefaultConnection']"
Write-Host ""
Write-Host "  3. Kor EF-migreringar mot Azure SQL efter deployment"
Write-Host ""
Write-Host "  4. Rensa resurser nar klart (behall resursgruppen):"
Write-Host "     az webapp delete --name $APP_NAME --resource-group $RESOURCE_GROUP"
Write-Host "     az appservice plan delete --name $PLAN --resource-group $RESOURCE_GROUP --yes"
Write-Host "     az sql server delete --name $SQL_SERVER --resource-group $RESOURCE_GROUP --yes"
Write-Host "     az storage account delete --name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP --yes"
Write-Host "     az keyvault delete --name $KV_NAME --resource-group $RESOURCE_GROUP"
Write-Host "     az monitor app-insights component delete --app $INSIGHTS_NAME --resource-group $RESOURCE_GROUP"
Write-Host "     az monitor log-analytics workspace delete --workspace-name $LAW_NAME --resource-group $RESOURCE_GROUP --yes"
Write-Host ""
Write-Host "============================================"