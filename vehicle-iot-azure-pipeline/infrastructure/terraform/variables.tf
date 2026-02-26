variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "rg-vehicle-iot-pipeline"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "storage_account_name" {
  description = "ADLS Gen2 storage account name (must be globally unique, lowercase, 3-24 chars)"
  type        = string
}

variable "key_vault_name" {
  description = "Azure Key Vault name (must be globally unique)"
  type        = string
}

variable "adf_name" {
  description = "Azure Data Factory name"
  type        = string
  default     = "adf-vehicle-iot-pipeline"
}

variable "sql_server_name" {
  description = "Azure SQL Server name (must be globally unique)"
  type        = string
}

variable "sql_database_name" {
  description = "Azure SQL Database name"
  type        = string
  default     = "vehicle-telemetry-db"
}

variable "sql_admin_username" {
  description = "SQL Server admin username"
  type        = string
  sensitive   = true
}

variable "sql_admin_password" {
  description = "SQL Server admin password"
  type        = string
  sensitive   = true
}

variable "function_app_name" {
  description = "Azure Function App name"
  type        = string
  default     = "func-blob-validator"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default = {
    Project     = "VehicleIoTPipeline"
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}
