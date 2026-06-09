USE NHTSA;
SET NOCOUNT ON;
GO
-- 1) Staging: all text, sized generously (big fields = MAX)
DROP TABLE IF EXISTS dbo.RecallsStg;
CREATE TABLE dbo.RecallsStg (
    RECORD_ID nvarchar(20), CAMPNO nvarchar(20), MAKETXT nvarchar(50), MODELTXT nvarchar(256),
    YEARTXT nvarchar(10), MFGCAMPNO nvarchar(30), COMPNAME nvarchar(256), MFGNAME nvarchar(60),
    BGMAN nvarchar(10), ENDMAN nvarchar(10), RCLTYPECD nvarchar(10), POTAFF nvarchar(20),
    ODATE nvarchar(10), INFLUENCED_BY nvarchar(10), MFGTXT nvarchar(60), RCDATE nvarchar(10),
    DATEA nvarchar(10), RPNO nvarchar(10), FMVSS nvarchar(10),
    DESC_DEFECT nvarchar(max), CONEQUENCE_DEFECT nvarchar(max), CORRECTIVE_ACTION nvarchar(max), NOTES nvarchar(max),
    RCL_CMPT_ID nvarchar(30), MFR_COMP_NAME nvarchar(60), MFR_COMP_DESC nvarchar(256), MFR_COMP_PTNO nvarchar(120),
    DO_NOT_DRIVE nvarchar(5), PARK_OUTSIDE nvarchar(5)
);
GO
BULK INSERT dbo.RecallsStg
FROM 'C:\ProgramData\NHTSA_Data\FLAT_RCL_POST_2010.txt'
WITH (FIELDTERMINATOR = '\t', ROWTERMINATOR = '0x0a', CODEPAGE = 'ACP', DATAFILETYPE = 'char', TABLOCK, MAXERRORS = 200);
SELECT COUNT(*) AS staged_rows FROM dbo.RecallsStg;
GO
-- 2) Typed table
DROP TABLE IF EXISTS dbo.Recalls;
CREATE TABLE dbo.Recalls (
    RecordID            int           NOT NULL,
    RecallNumber        nvarchar(20),
    Make                nvarchar(50),
    Model               nvarchar(256),
    ModelYear           smallint      NULL,
    Component           nvarchar(256),
    Manufacturer        nvarchar(60),
    MfgStart            date          NULL,
    MfgEnd              date          NULL,
    RecallType          nvarchar(10),
    UnitsAffected       int           NULL,
    OwnerNotifiedDate   date          NULL,
    ReportReceivedDate  date          NULL,
    RecordCreated       date          NULL,
    FMVSS               nvarchar(10),
    DefectDesc          nvarchar(max),
    ConsequenceDesc     nvarchar(max),
    CorrectiveAction    nvarchar(max),
    Notes               nvarchar(max),
    DoNotDrive          nvarchar(5),
    ParkOutside         nvarchar(5)
);
GO
INSERT INTO dbo.Recalls
SELECT TRY_CONVERT(int, RECORD_ID), CAMPNO, MAKETXT, MODELTXT,
       TRY_CONVERT(smallint, NULLIF(YEARTXT,'')), COMPNAME, MFGNAME,
       TRY_CONVERT(date, NULLIF(BGMAN,''), 112), TRY_CONVERT(date, NULLIF(ENDMAN,''), 112),
       RCLTYPECD, TRY_CONVERT(int, NULLIF(POTAFF,'')),
       TRY_CONVERT(date, NULLIF(ODATE,''), 112), TRY_CONVERT(date, NULLIF(RCDATE,''), 112),
       TRY_CONVERT(date, NULLIF(DATEA,''), 112), FMVSS,
       DESC_DEFECT, CONEQUENCE_DEFECT, CORRECTIVE_ACTION, NOTES,
       NULLIF(DO_NOT_DRIVE,''), NULLIF(REPLACE(PARK_OUTSIDE, CHAR(13), ''), '')
FROM dbo.RecallsStg
WHERE TRY_CONVERT(int, RECORD_ID) IS NOT NULL;
GO
ALTER TABLE dbo.Recalls ADD CONSTRAINT PK_Recalls PRIMARY KEY CLUSTERED (RecordID);
GO
SELECT COUNT(*) AS recalls_rows,
       SUM(CASE WHEN DefectDesc IS NOT NULL AND LEN(DefectDesc)>0 THEN 1 ELSE 0 END) AS has_defect_text,
       MIN(ModelYear) AS min_year, MAX(ModelYear) AS max_year
FROM dbo.Recalls;
SELECT TOP 2 RecordID, RecallNumber, Make, Model, ModelYear, Component, UnitsAffected, LEFT(DefectDesc,80) AS defect
FROM dbo.Recalls WHERE Make='FORD' ORDER BY RecordID DESC;
GO
