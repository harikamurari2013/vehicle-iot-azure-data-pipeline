# Setup Guide — Vehicle IoT Azure Data Pipeline

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Azure Resource Setup](#azure-resource-setup)
3. [Key Vault Configuration](#key-vault-configuration)
4. [Pipeline 1: S3 → ADLS Landing](#pipeline-1-s3--adls-landing)
5. [Azure Function Deployment](#azure-function-deployment)
6. [Pipeline 2: Staging → SQL Server](#pipeline-2-staging--sql-server)
7. [Trigger Chain Configuration](#trigger-chain-configuration)
8. [Validation & Testing](#validation--testing)

---

## Prerequisites

- Azure CLI installed: `az --version`
- Terraform >= 1.3: `terraform --version`
- Node.js >= 16: `node --version`
- Azure Functions Core Tools: `func --version`
- AWS CLI with S3 read access configured

---

## Azure Resource Setup

### Option A: Terraform (Recommended)
```bash
cd infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform apply
```

### Option B: Azure CLI Manual
```bash
# Variables
RG="rg-vehicle-iot-pipeline"
LOCATION="eastus"
STORAGE="vehicleiotadls"
KV="kv-vehicle-iot"
ADF="adf-vehicle-iot"
SQL_SERVER="sql-vehicle-iot"

# Resource Group
az group create --name $RG --location $LOCATION

# ADLS Gen2
az storage account create \
  --name $STORAGE \
  --resource-group $RG \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2 \
  --enable-hierarchical-namespace true

# Create containers
az storage container create --name landing --account-name $STORAGE
az storage container create --name staging --account-name $STORAGE
az storage container create --name rejected --account-name $STORAGE

# Key Vault
az keyvault create --name $KV --resource-group $RG --location $LOCATION

# ADF
az datafactory create --factory-name $ADF --resource-group $RG --location $LOCATION
```

---

## Key Vault Configuration

Store AWS credentials and SQL connection string securely:

```bash
# AWS credentials for S3 access
az keyvault secret set \
  --vault-name $KV \
  --name "aws-access-key-id" \
  --value "<YOUR_AWS_ACCESS_KEY_ID>"

az keyvault secret set \
  --vault-name $KV \
  --name "aws-secret-access-key" \
  --value "<YOUR_AWS_SECRET_ACCESS_KEY>"

# SQL Server connection string
az keyvault secret set \
  --vault-name $KV \
  --name "sql-server-connection-string" \
  --value "Server=tcp:$SQL_SERVER.database.windows.net;Database=vehicle-telemetry-db;..."

# Grant ADF Managed Identity access to Key Vault
ADF_PRINCIPAL_ID=$(az datafactory show \
  --name $ADF \
  --resource-group $RG \
  --query "identity.principalId" -o tsv)

az keyvault set-policy \
  --name $KV \
  --object-id $ADF_PRINCIPAL_ID \
  --secret-permissions get list
```

---

## Pipeline 1: S3 → ADLS Landing

### Import ARM Template to ADF
1. Navigate to ADF Studio → **Author** → **...** → **Import from ARM template**
2. Upload `adf-pipelines/pipeline1_s3_to_adls.json`
3. Set parameters: `s3BucketName`, `adlsStorageAccountName`

### Configure Linked Services
In ADF Studio:
- **LS_AzureKeyVault**: Auto-configured from template using ADF Managed Identity
- **LS_AmazonS3**: Uses Key Vault references for `aws-access-key-id` and `aws-secret-access-key`
- **LS_ADLS_Gen2**: Uses ADF Managed Identity (grant Storage Blob Data Contributor role)

```bash
# Grant ADF access to ADLS
az role assignment create \
  --assignee $ADF_PRINCIPAL_ID \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/<sub-id>/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/$STORAGE"
```

---

## Azure Function Deployment

```bash
cd azure-functions/BlobTriggerValidator
npm install

# Deploy to Azure
func azure functionapp publish func-blob-validator

# Verify deployment
az functionapp list --resource-group $RG --query "[].{Name:name, State:state}"
```

### Verify Blob Trigger Bindings
In Azure Portal → Function App → Functions → BlobTriggerValidator → Integration:
- **Trigger**: Azure Blob Storage — `input/landing/{name}`
- **Output 1** (stagingFolder): Azure Blob Storage — `staging/{name}`
- **Output 2** (rejectedFolder): Azure Blob Storage — `rejected/{name}`

---

## Pipeline 2: Staging → SQL Server

### Create Target Tables
```bash
# Run SQL DDL against your Azure SQL Server
sqlcmd -S $SQL_SERVER.database.windows.net \
       -d vehicle-telemetry-db \
       -U <admin_user> \
       -P <admin_password> \
       -i sql-scripts/create_tables.sql
```

### Create Pipeline 2 in ADF
1. ADF Studio → **Author** → **+** → **Pipeline**
2. Add **Copy Data** activity
3. Source: ADLS Gen2 Linked Service, path = `staging/`
4. Sink: Azure SQL Server Linked Service (connection string from Key Vault)

---

## Trigger Chain Configuration

### Storage Event Trigger (Pipeline 2 auto-starts after staging writes)
1. ADF Studio → **Manage** → **Triggers** → **+ New**
2. Type: **Storage Event Trigger**
3. Storage account: Select your ADLS Gen2
4. Container name: `staging`
5. Blob path begins with: `/` (catch all staging files)
6. Event: **Blob created**
7. Associate with: **Pipeline 2 (PL_Staging_To_SQL)**
8. Publish all → Activate trigger

---

## Validation & Testing

### End-to-End Test
```bash
# 1. Upload a valid test JSON to S3
aws s3 cp tests/sample_valid.json s3://<your-bucket>/vehicles/test_001.json

# 2. Manually trigger Pipeline 1 in ADF Studio
# 3. Verify file appears in ADLS landing/
az storage blob list --container-name landing --account-name $STORAGE

# 4. Check Azure Function logs
az monitor activity-log list --resource-group $RG

# 5. Verify file moved to staging/
az storage blob list --container-name staging --account-name $STORAGE

# 6. Check Pipeline 2 ran automatically in ADF Monitor

# 7. Query SQL Server
sqlcmd -S $SQL_SERVER.database.windows.net -d vehicle-telemetry-db \
       -Q "SELECT TOP 10 * FROM dbo.VehicleTelemetry ORDER BY IngestedAt DESC"
```

### Test with Invalid JSON
```bash
# Upload an invalid file — should go to rejected/
echo "this is not valid json {" > /tmp/invalid.json
aws s3 cp /tmp/invalid.json s3://<your-bucket>/vehicles/invalid_001.json

# Verify it lands in rejected/ container
az storage blob list --container-name rejected --account-name $STORAGE
```
