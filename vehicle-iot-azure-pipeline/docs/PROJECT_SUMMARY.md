# Project Summary — Vehicle IoT Azure Data Pipeline

This document describes the Azure resources provisioned, pipelines configured, and data successfully processed through this pipeline.

---

## What Was Built

An end-to-end data pipeline that ingests real-time vehicle IoT sensor data from **AWS S3** into **Azure SQL Server** — fully automated with zero manual intervention after initial setup.

---

## Azure Resources Provisioned

All resources deployed under a single **Resource Group**.

| Resource | Purpose |
|---|---|
| AWS S3 Bucket | Source of vehicle IoT sensor data, structured by `year/month/date/file` |
| Azure Key Vault | Stores AWS IAM access keys as secrets for secure cross-cloud connectivity |
| ADLS Gen2 | Data lake with three containers: `landing`, `staging`, `rejected` |
| Azure Data Factory | Orchestrates both pipelines |
| Azure Function App | Blob Trigger — validates JSON on landing, routes to staging or rejected |
| Azure SQL Server | Final destination for validated vehicle records |

---

## Data Flow — Step by Step

### Step 1 — IoT Sensors → AWS S3
Vehicle IoT sensors stream data into an AWS S3 bucket. Files are organised by `year/month/date/file` folder structure.

### Step 2 — Store AWS Credentials in Azure Key Vault
AWS IAM access keys retrieved from IAM console and stored in Azure Key Vault as secrets:
- `aws-access-key-id`
- `aws-secret-access-key`

ADF uses these Key Vault references in its Linked Service — no credentials hardcoded anywhere.

### Step 3 — ADF Pipeline 1: S3 → ADLS Gen2 Landing
- **Source**: AWS S3 Linked Service (credentials from Key Vault)
- **Sink**: ADLS Gen2 `landing` container
- Copy Activity moves JSON files from S3 into the landing zone

### Step 4 — Azure Function: Blob Trigger Validator
Fires automatically when a new file arrives in `landing/`.

**Validation logic:**
- Attempts to parse the blob content as JSON
- If **valid JSON** → copies file to `staging/` container
- If **invalid JSON** → copies file to `rejected/` container

**Function code deployed:**
```javascript
module.exports = async function (context, myBlob) {
    context.log("JavaScript blob trigger function processed blob \n Blob:");
    context.log("********Azure Function Started********");
    var result = true;
    try {
        context.log(myBlob.toString());
        JSON.parse(myBlob.toString().trim().replace('\n', ' '));
    } catch(exception) {
        context.log(exception);
        result = false;
    }
    if (result) {
        context.bindings.stagingFolder = myBlob.toString();
        context.log("********File Copied to Staging Folder Successfully********");
    } else {
        context.bindings.rejectedFolder = myBlob.toString();
        context.log("********Inavlid JSON File Copied to Rejected Folder Successfully********");
    }
    context.log("*******Azure Function Ended Successfully*******");
};
```

### Step 5 — ADF Pipeline 2: Staging → Azure SQL Server
- **Source**: ADLS Gen2 `staging/` container
- **Sink**: Azure SQL Server `dbo.VehicleTelemetry` table
- **Trigger**: Storage Event Trigger — fires automatically whenever a new file is written to `staging/`
- Field mappings handle the real Customer.json schema: `VehicleID`, `latitiude`, `longitude`, `City`, `temeprature`, `speed`

---

## Sample Data

**500 vehicle records** processed through the full pipeline end-to-end. See [`notebooks/Customer.json`](../notebooks/Customer.json) for the actual dataset used.

**Schema (Customer.json):**
```json
{
  "VehicleID": "SK4523820602745727881887",
  "latitiude": 86.8332365824,
  "longitude": -78.5162003456,
  "City": "Mérignac",
  "temeprature": 82,
  "speed": 191
}
```

---

## Key Technical Decisions

| Decision | Reason |
|---|---|
| AWS IAM keys stored in Azure Key Vault | Zero hardcoded credentials — fully auditable, secure cross-cloud access |
| Azure Function as Blob Trigger | Event-driven — no polling, fires instantly on file arrival |
| Storage Event Trigger on Pipeline 2 | Automatically chains Pipeline 2 after Azure Function writes to staging |
| Dead-letter pattern (rejected/ folder) | Bad files are quarantined for review, pipeline never blocks |
| ADLS Gen2 as landing zone | Acts as a buffer between raw S3 data and SQL — enables reprocessing if needed |

---

## Result

All 500 vehicle records successfully ingested from AWS S3, validated through the Azure Function, loaded into Azure SQL Server `dbo.VehicleTelemetry` table via the Storage Event Trigger chain.
