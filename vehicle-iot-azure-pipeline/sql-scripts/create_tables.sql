-- ============================================================
-- Vehicle IoT Telemetry — Azure SQL Server DDL
-- Matches Customer.json schema
-- Fields: VehicleID, latitiude, longitude, City, temeprature, speed
-- ============================================================

CREATE TABLE dbo.VehicleTelemetry (
    Id            BIGINT IDENTITY(1,1) PRIMARY KEY,
    VehicleID     NVARCHAR(100)   NOT NULL,
    Latitude      FLOAT           NOT NULL,
    Longitude     FLOAT           NOT NULL,
    City          NVARCHAR(200)   NOT NULL,
    Temperature   INT             NOT NULL,
    Speed         INT             NOT NULL,
    IngestedAt    DATETIME2       NOT NULL DEFAULT GETUTCDATE(),
    SourceFile    NVARCHAR(500),
    INDEX IX_VehicleID (VehicleID),
    INDEX IX_City (City)
);
GO

-- Dead-letter table for rejected files
CREATE TABLE dbo.RejectedFiles (
    Id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    FileName        NVARCHAR(500)   NOT NULL,
    RejectedAt      DATETIME2       NOT NULL DEFAULT GETUTCDATE(),
    RejectionReason NVARCHAR(1000),
    RawContent      NVARCHAR(MAX)
);
GO
