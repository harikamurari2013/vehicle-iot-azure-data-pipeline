# 🚗 Vehicle IoT Data Pipeline — Azure End-to-End Data Engineering Project

![Azure](https://img.shields.io/badge/Azure-Data%20Factory-0078D4?style=flat&logo=microsoftazure)
![AWS](https://img.shields.io/badge/AWS-S3-FF9900?style=flat&logo=amazonaws)
![Azure Functions](https://img.shields.io/badge/Azure-Functions-0062AD?style=flat&logo=azurefunctions)
![SQL Server](https://img.shields.io/badge/Azure-SQL%20Server-CC2927?style=flat&logo=microsoftsqlserver)
![ADLS Gen2](https://img.shields.io/badge/Azure-ADLS%20Gen2-0078D4?style=flat&logo=microsoftazure)
![Status](https://img.shields.io/badge/Status-Completed-brightgreen)

---

## 📌 Project Overview

An end-to-end **event-driven data pipeline** that ingests real-time vehicle IoT sensor data from **AWS S3** into **Azure SQL Server** — orchestrated via Azure Data Factory, validated using a serverless Azure Function, and secured with Azure Key Vault.

**500 vehicle records** successfully processed through the full pipeline end-to-end.

---

## 🏗️ Architecture

```
IoT Sensors → AWS S3 (year/month/date/file)
                    ↓
       ADF Pipeline 1 (S3 → ADLS Gen2 Landing)
       [AWS Keys stored in Azure Key Vault]
                    ↓
         Azure Function — Blob Trigger
         (fires on every new file in landing/)
              ↙               ↘
         staging/           rejected/
       (valid JSON)       (invalid JSON)
              ↓
       ADF Pipeline 2 (staging → Azure SQL Server)
       [Storage Event Trigger — fully automated]
```

---

## 🔧 Tech Stack

| Layer | Technology |
|---|---|
| IoT Source | AWS S3 |
| Secret Management | Azure Key Vault |
| Orchestration | Azure Data Factory |
| Storage | ADLS Gen2 (`landing`, `staging`, `rejected`) |
| Validation | Azure Functions (Node.js — Blob Trigger) |
| Serving Layer | Azure SQL Server |
| IaC | Terraform |
| CI/CD | GitHub Actions |

---

## 📁 Repository Structure

```
vehicle-iot-azure-pipeline/
│
├── adf-pipelines/
│   ├── pipeline1_s3_to_adls.json       # S3 → ADLS Gen2 Landing
│   └── pipeline2_staging_to_sql.json   # Staging → Azure SQL (Storage Event Trigger)
│
├── azure-functions/
│   └── BlobTriggerValidator/
│       ├── index.js                    # Blob trigger — validates JSON, routes to staging/rejected
│       ├── function.json               # Bindings: landing (in), staging/rejected (out)
│       └── package.json
│
├── infrastructure/
│   └── terraform/
│       ├── main.tf                     # All Azure resources
│       └── variables.tf
│
├── sql-scripts/
│   └── create_tables.sql               # dbo.VehicleTelemetry DDL
│
├── notebooks/
│   ├── Customer.json                   # 500 real vehicle records (actual data used)
│   └── sample_vehicle_payload.json     # 3-record sample
│
├── docs/
│   └── PROJECT_SUMMARY.md             # What was built, run, and the results
│
└── .github/
    └── workflows/
        └── deploy.yml                  # CI/CD — test, plan, deploy
```

---

## ⚡ How the Pipeline Works

### Pipeline 1 — AWS S3 → ADLS Gen2 Landing
ADF uses a Linked Service connected to AWS S3. AWS IAM access keys are stored in **Azure Key Vault** — never hardcoded. Files are copied from S3 into the ADLS Gen2 `landing` container.

### Azure Function — Blob Trigger Validator
Fires automatically the moment a file lands in `landing/`. Attempts to parse the content as JSON:
- **Valid** → writes to `staging/`
- **Invalid** → writes to `rejected/` (dead-letter)

### Pipeline 2 — Staging → Azure SQL Server
A **Storage Event Trigger** fires automatically whenever the Azure Function writes a valid file to `staging/`. ADF copies the validated records into `dbo.VehicleTelemetry` in Azure SQL Server. No manual trigger needed.

---

## 🔐 Security

AWS credentials are stored in Azure Key Vault and referenced by ADF Linked Services — zero hardcoded secrets anywhere in the pipeline.

---

## 📊 Sample Data Schema (Customer.json)

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

500 records processed. See [`notebooks/Customer.json`](vehicle-iot-azure-pipeline/notebooks/Customer.json) for the full dataset.

---

## 📄 Project Summary

Full details of resources provisioned, pipeline configuration, and results:
👉 [`docs/PROJECT_SUMMARY.md`](vehicle-iot-azure-pipeline/docs/PROJECT_SUMMARY.md)
