USE NHTSA;
SET NOCOUNT ON;
GO
-- Recall narratives: one row per distinct campaign (defect text is campaign-level)
DROP TABLE IF EXISTS dbo.RecallVectors;
CREATE TABLE dbo.RecallVectors (
    RecallVecID  int IDENTITY(1,1) NOT NULL CONSTRAINT PK_RecallVectors PRIMARY KEY CLUSTERED,
    RecallNumber nvarchar(20)  NOT NULL,
    Narrative    nvarchar(max) NOT NULL,
    Embedding    vector(768)   NULL
);
INSERT INTO dbo.RecallVectors (RecallNumber, Narrative)
SELECT RecallNumber,
       LEFT(CONCAT(MAX(Component), '. ', MAX(DefectDesc), ' ', MAX(ConsequenceDesc)), 3000)
FROM dbo.Recalls
WHERE DefectDesc IS NOT NULL AND LEN(DefectDesc) > 0
GROUP BY RecallNumber;
SELECT 'RecallVectors' AS tbl, COUNT(*) AS rows_to_embed FROM dbo.RecallVectors;
GO
-- Complaint narratives: Ford Expedition (personal subset)
DROP TABLE IF EXISTS dbo.ComplaintVectors;
CREATE TABLE dbo.ComplaintVectors (
    ComplaintRowID int           NOT NULL CONSTRAINT PK_ComplaintVectors PRIMARY KEY CLUSTERED,
    Narrative      nvarchar(max) NOT NULL,
    Embedding      vector(768)   NULL
);
INSERT INTO dbo.ComplaintVectors (ComplaintRowID, Narrative)
SELECT ComplaintRowID, LEFT(Narrative, 3000)
FROM dbo.Complaints
WHERE Make = 'FORD' AND Model LIKE 'EXPEDITION%' AND Narrative IS NOT NULL AND LEN(Narrative) > 0;
SELECT 'ComplaintVectors' AS tbl, COUNT(*) AS rows_to_embed FROM dbo.ComplaintVectors;
GO
