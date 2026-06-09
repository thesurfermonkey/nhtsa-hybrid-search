USE NHTSA;
SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;
SET NOCOUNT ON;
ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
GO
-- External model for query-time embedding (proxy already running)
IF EXISTS (SELECT 1 FROM sys.external_models WHERE name='OllamaNomic') DROP EXTERNAL MODEL OllamaNomic;
GO
CREATE EXTERNAL MODEL OllamaNomic AUTHORIZATION dbo
WITH (LOCATION='https://localhost:11443/api/embed', API_FORMAT='Ollama', MODEL_TYPE=EMBEDDINGS, MODEL='nomic-embed-text:latest');
GO
PRINT '=== Top 10 makes by complaint count ===';
SELECT TOP (10) Make, COUNT(*) AS complaints FROM dbo.Complaints GROUP BY Make ORDER BY complaints DESC;
PRINT '';
PRINT '=== Your Ford Expedition: top components complained about ===';
SELECT TOP (10) Component, COUNT(*) AS n FROM dbo.Complaints
WHERE Make='FORD' AND Model LIKE 'EXPEDITION%' GROUP BY Component ORDER BY n DESC;
PRINT '';
PRINT '=== Complaints involving fire, by make (top 8) ===';
SELECT TOP (8) Make, COUNT(*) AS fire_complaints FROM dbo.Complaints WHERE Fire='Y' GROUP BY Make ORDER BY fire_complaints DESC;
PRINT '';
PRINT '=== Recent "Do Not Drive" recalls ===';
SELECT TOP (5) RecallNumber, Make, Model, ModelYear, Component, LEFT(DefectDesc,60) AS defect
FROM dbo.Recalls WHERE DoNotDrive='Yes' ORDER BY ReportReceivedDate DESC;
GO
