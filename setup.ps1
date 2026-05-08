# =============================================================
#  Assignment 1 - Azure App Service Deployment
#  Auctionhouse API
#  Run: .\setup.ps1
# =============================================================

$ErrorActionPreference = "Continue"

# =============================================================
#  CONFIGURATION - Change as needed
# =============================================================
$RESOURCE_GROUP = "RG-Jakob-El-Saidi-0900c0-DotNetCloudDeveloper-VT-Mars-Goteborg"
$LOCATION = "swedencentral"
$PLAN = "plan-auctionhouse500"
$APP_NAME = "auctionhouse-api-dev500"
$SQL_SERVER = "auctionhouse-sql-dev500"
$SQL_DB = "AuctionHouseDB"
$SQL_USER = "sqladmin"
$SQL_PASSWORD = "BajsBajs123!"
$STORAGE_ACCOUNT = "stauctionhousedev500"
$KV_NAME = "kv-auctionhouse-dev500"
$INSIGHTS_NAME = "appi-auctionhouse500"
$LAW_NAME = "law-auctionhouse500"
$SUBSCRIPTION_ID = "457c50ad-2cb0-4bed-9fea-fbdf6eed15bf"

Write-Host "============================================"
Write-Host " Starting deployment..."
Write-Host " App:     $APP_NAME"
Write-Host " SQL:     $SQL_SERVER"
Write-Host " Storage: $STORAGE_ACCOUNT"
Write-Host " KV:      $KV_NAME"
Write-Host "============================================"

# =============================================================
#  STEP 1 - APP SERVICE & SQL
# =============================================================

Write-Host ">>> Creating App Service Plan (B1)..."
az appservice plan create --name $PLAN --resource-group $RESOURCE_GROUP --sku B1 --location $LOCATION

Write-Host ">>> Creating App Service..."
az webapp create --name $APP_NAME --resource-group $RESOURCE_GROUP --plan $PLAN --runtime "dotnet:10"

Write-Host ">>> Creating SQL Server..."
az sql server create --name $SQL_SERVER --resource-group $RESOURCE_GROUP --location $LOCATION --admin-user $SQL_USER --admin-password $SQL_PASSWORD

Write-Host ">>> Waiting for SQL Server to be ready (30s)..."
Start-Sleep -Seconds 30

Write-Host ">>> Firewall - allow Azure services..."
az sql server firewall-rule create --name AllowAzureServices --resource-group $RESOURCE_GROUP --server $SQL_SERVER --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0

Write-Host ">>> Firewall - allow your IP..."
$MY_IP = (Invoke-WebRequest -Uri https://api.ipify.org -UseBasicParsing).Content.Trim()
az sql server firewall-rule create --name AllowMyIP --resource-group $RESOURCE_GROUP --server $SQL_SERVER --start-ip-address $MY_IP --end-ip-address $MY_IP

Write-Host ">>> Creating database (Basic)..."
az sql db create --name $SQL_DB --resource-group $RESOURCE_GROUP --server $SQL_SERVER --edition Basic

# =============================================================
#  STEP 2 - APPLICATION INSIGHTS
# =============================================================

Write-Host ">>> Creating Log Analytics Workspace (PerGB2018)..."
az monitor log-analytics workspace create --name $LAW_NAME --resource-group $RESOURCE_GROUP --location $LOCATION --sku PerGB2018

Write-Host ">>> Creating Application Insights..."
az monitor app-insights component create --app $INSIGHTS_NAME --location $LOCATION --resource-group $RESOURCE_GROUP --workspace $LAW_NAME

Write-Host ">>> Waiting for Application Insights to be ready (15s)..."
Start-Sleep -Seconds 15

$CONN_STR = az monitor app-insights component show --app $INSIGHTS_NAME --resource-group $RESOURCE_GROUP --query connectionString --output tsv

# =============================================================
#  STEP 3 - SECURITY
# =============================================================

Write-Host ">>> IP restriction - your IP: $MY_IP"
az webapp config access-restriction add --name $APP_NAME --resource-group $RESOURCE_GROUP --rule-name AllowMyIP --action Allow --ip-address "${MY_IP}/32" --priority 100

Write-Host ">>> Enabling HTTPS-only..."
az webapp update --name $APP_NAME --resource-group $RESOURCE_GROUP --https-only true

Write-Host ">>> Setting minimum TLS version to 1.2..."
az webapp config set --name $APP_NAME --resource-group $RESOURCE_GROUP --min-tls-version 1.2

# =============================================================
#  STEP 4 - STORAGE ACCOUNT
# =============================================================

Write-Host ">>> Creating Storage Account for backups..."
az storage account create --name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP --location $LOCATION --sku Standard_LRS --kind StorageV2 --allow-shared-key-access true

$STORAGE_KEY = az storage account keys list --account-name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP --query "[0].value" --output tsv

Write-Host ">>> Creating backup container..."
az storage container create --name backups --account-name $STORAGE_ACCOUNT --account-key $STORAGE_KEY --public-access off

Write-Host ">>> Generating SAS token..."
$SAS = (az storage container generate-sas --account-name $STORAGE_ACCOUNT --account-key $STORAGE_KEY --name backups --permissions rwdl --expiry 2099-12-31 --output tsv).Trim()
$env:AZURE_BACKUP_URL = "https://${STORAGE_ACCOUNT}.blob.core.windows.net/backups?$($SAS -replace '&', '%26')"

Write-Host ">>> Creating initial backup..."
az webapp config backup create --resource-group $RESOURCE_GROUP --webapp-name $APP_NAME --container-url $env:AZURE_BACKUP_URL

Write-Host ">>> Waiting for backup to initialize (30s)..."
Start-Sleep -Seconds 30

Write-Host ">>> Scheduling daily backup..."
az webapp config backup update --resource-group $RESOURCE_GROUP --webapp-name $APP_NAME --container-url $env:AZURE_BACKUP_URL --frequency 1d --retention 30 --retain-one true

Write-Host ">>> Storage Account $STORAGE_ACCOUNT used for:"
Write-Host "    - Daily backups (container: backups)"
Write-Host "    - Can be extended with containers for static files/logs"

# =============================================================
#  STEP 5 - KEY VAULT & MANAGED IDENTITY
# =============================================================

Write-Host ">>> Creating Key Vault..."
az keyvault create --name $KV_NAME --resource-group $RESOURCE_GROUP --location $LOCATION --sku standard --enable-rbac-authorization true

Write-Host ">>> Assigning Key Vault Secrets Officer role to yourself..."
$USER_EMAIL = az account show --query user.name --output tsv
az role assignment create --assignee $USER_EMAIL --role "Key Vault Secrets Officer" --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KV_NAME

Write-Host ">>> Waiting for role to propagate (15s)..."
Start-Sleep -Seconds 15

Write-Host ">>> Storing connection string as secret..."
az keyvault secret set --vault-name $KV_NAME --name DefaultConnection --value "Server=tcp:${SQL_SERVER}.database.windows.net,1433;Initial Catalog=${SQL_DB};User ID=${SQL_USER};Password=${SQL_PASSWORD};Encrypt=True;TrustServerCertificate=False"

Write-Host ">>> Enabling Managed Identity on App Service..."
az webapp identity assign --name $APP_NAME --resource-group $RESOURCE_GROUP

Write-Host ">>> Waiting for Managed Identity to propagate (120s)..."
Start-Sleep -Seconds 120

$PRINCIPAL_ID = az webapp identity show --name $APP_NAME --resource-group $RESOURCE_GROUP --query principalId --output tsv

Write-Host ">>> Assigning Key Vault Secrets User role to App Service..."
az role assignment create --assignee-object-id $PRINCIPAL_ID --assignee-principal-type ServicePrincipal --role "Key Vault Secrets User" --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KV_NAME

$SECRET_URI = az keyvault secret show --vault-name $KV_NAME --name DefaultConnection --query id --output tsv

Write-Host ">>> Setting App Service environment variables via REST API..."
$TOKEN = (az account get-access-token --query accessToken --output tsv)
$KV_REF = '@Microsoft.KeyVault(SecretUri=' + $SECRET_URI + ')'
$BODY = @{
  properties = @{
    DefaultConnection                     = $KV_REF
    APPLICATIONINSIGHTS_CONNECTION_STRING = $CONN_STR
  }
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Method PUT `
  -Uri "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$APP_NAME/config/appsettings?api-version=2022-03-01" `
  -Headers @{ Authorization = "Bearer $TOKEN"; "Content-Type" = "application/json" } `
  -Body $BODY

# =============================================================
#  GITHUB ACTIONS SERVICE PRINCIPAL
# =============================================================

Write-Host ">>> Creating service principal for GitHub Actions..."
$SP_OUTPUT = az ad sp create-for-rbac --name "github-actions-auctionhouse" --role contributor --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP --sdk-auth

# =============================================================
#  DONE!
# =============================================================

Write-Host ""
Write-Host "============================================"
Write-Host " DEPLOYMENT COMPLETE!"
Write-Host "============================================"
Write-Host ""
Write-Host "  App Service URL: https://$APP_NAME.azurewebsites.net"
Write-Host ""
Write-Host "============================================"
Write-Host " GITHUB ACTIONS - Service Principal JSON:"
Write-Host " Copy the block below and add as GitHub Secret (AZURE_CREDENTIALS):"
Write-Host "============================================"
Write-Host $SP_OUTPUT
Write-Host "============================================"
Write-Host ""
Write-Host "  MANUAL STEPS REMAINING:"
Write-Host ""
Write-Host "  1. GitHub Actions:"
Write-Host "     - Copy the JSON above -> GitHub -> Settings -> Secrets -> Actions"
Write-Host "     - Create secret: AZURE_CREDENTIALS"
Write-Host "     - Ensure .github/workflows/azure-deploy.yml exists in repo root"
Write-Host ""
Write-Host "  2. Code changes in the project:"
Write-Host "     - dotnet add package Azure.Monitor.OpenTelemetry.AspNetCore"
Write-Host "     - Add: builder.Services.AddOpenTelemetry().UseAzureMonitor();"
Write-Host "     - Change GetConnectionString to builder.Configuration"
Write-Host ""
Write-Host "  3. Run EF migrations against Azure SQL after deployment"
Write-Host ""
Write-Host "  4. Clean up resources when done (keep resource group):"
Write-Host "     az webapp delete --name $APP_NAME --resource-group $RESOURCE_GROUP"
Write-Host "     az appservice plan delete --name $PLAN --resource-group $RESOURCE_GROUP --yes"
Write-Host "     az sql server delete --name $SQL_SERVER --resource-group $RESOURCE_GROUP --yes"
Write-Host "     az storage account delete --name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP --yes"
Write-Host "     az keyvault delete --name $KV_NAME --resource-group $RESOURCE_GROUP"
Write-Host "     az monitor app-insights component delete --app $INSIGHTS_NAME --resource-group $RESOURCE_GROUP"
Write-Host "     az monitor log-analytics workspace delete --workspace-name $LAW_NAME --resource-group $RESOURCE_GROUP --yes"
Write-Host ""
Write-Host "============================================"