USE NHTSA;
SET NOCOUNT ON;
ALTER DATABASE NHTSA SET RECOVERY SIMPLE;
GO
DROP TABLE IF EXISTS dbo.ComplaintsStg;
CREATE TABLE dbo.ComplaintsStg (
    CMPLID nvarchar(12), ODINO nvarchar(12), MFR_NAME nvarchar(60), MAKETXT nvarchar(40), MODELTXT nvarchar(256),
    YEARTXT nvarchar(10), CRASH nvarchar(2), FAILDATE nvarchar(10), FIRE nvarchar(2), INJURED nvarchar(6),
    DEATHS nvarchar(6), COMPDESC nvarchar(160), CITY nvarchar(40), STATE nvarchar(4), VIN nvarchar(15),
    DATEA nvarchar(10), LDATE nvarchar(10), MILES nvarchar(12), OCCURENCES nvarchar(10), CDESCR nvarchar(max),
    CMPL_TYPE nvarchar(6), POLICE_RPT_YN nvarchar(2), PURCH_DT nvarchar(10), ORIG_OWNER_YN nvarchar(2),
    ANTI_BRAKES_YN nvarchar(2), CRUISE_CONT_YN nvarchar(2), NUM_CYLS nvarchar(4), DRIVE_TRAIN nvarchar(6),
    FUEL_SYS nvarchar(6), FUEL_TYPE nvarchar(6), TRANS_TYPE nvarchar(6), VEH_SPEED nvarchar(6), DOT nvarchar(24),
    TIRE_SIZE nvarchar(40), LOC_OF_TIRE nvarchar(6), TIRE_FAIL_TYPE nvarchar(6), ORIG_EQUIP_YN nvarchar(2),
    MANUF_DT nvarchar(10), SEAT_TYPE nvarchar(6), RESTRAINT_TYPE nvarchar(6), DEALER_NAME nvarchar(60),
    DEALER_TEL nvarchar(24), DEALER_CITY nvarchar(40), DEALER_STATE nvarchar(4), DEALER_ZIP nvarchar(12),
    PROD_TYPE nvarchar(6), REPAIRED_YN nvarchar(2), MEDICAL_ATTN nvarchar(2), VEHICLES_TOWED_YN nvarchar(2),
    STATE_OF_INCIDENT nvarchar(4), VEHICLE_OPERATOR nvarchar(60)
);
GO
BULK INSERT dbo.ComplaintsStg
FROM 'C:\ProgramData\NHTSA_Data\FLAT_CMPL.txt'
WITH (FIELDTERMINATOR = '\t', ROWTERMINATOR = '0x0a', CODEPAGE = 'ACP', DATAFILETYPE = 'char', TABLOCK, MAXERRORS = 500);
SELECT COUNT(*) AS staged_rows FROM dbo.ComplaintsStg;
GO
DROP TABLE IF EXISTS dbo.Complaints;
CREATE TABLE dbo.Complaints (
    ComplaintRowID  int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Complaints PRIMARY KEY CLUSTERED,
    CmplID          int,
    Manufacturer    nvarchar(60),
    Make            nvarchar(40),
    Model           nvarchar(256),
    ModelYear       smallint NULL,
    Crash           char(1),
    Fire            char(1),
    Injured         smallint NULL,
    Deaths          smallint NULL,
    Component       nvarchar(160),
    City            nvarchar(40),
    State           nvarchar(4),
    FailDate        date NULL,
    DateAdded       date NULL,
    ReceiptDate     date NULL,
    Miles           int NULL,
    VehSpeed        smallint NULL,
    ComplaintType   nvarchar(6),
    PoliceReport    char(1),
    MedicalAttn     char(1),
    VehiclesTowed   char(1),
    StateOfIncident nvarchar(4),
    Narrative       nvarchar(max)
);
GO
INSERT INTO dbo.Complaints
    (CmplID, Manufacturer, Make, Model, ModelYear, Crash, Fire, Injured, Deaths, Component, City, State,
     FailDate, DateAdded, ReceiptDate, Miles, VehSpeed, ComplaintType, PoliceReport, MedicalAttn, VehiclesTowed,
     StateOfIncident, Narrative)
SELECT TRY_CONVERT(int, NULLIF(CMPLID,'')), MFR_NAME, MAKETXT, MODELTXT,
       TRY_CONVERT(smallint, NULLIF(YEARTXT,'')), NULLIF(CRASH,''), NULLIF(FIRE,''),
       TRY_CONVERT(smallint, NULLIF(INJURED,'')), TRY_CONVERT(smallint, NULLIF(DEATHS,'')),
       COMPDESC, CITY, STATE,
       TRY_CONVERT(date, NULLIF(FAILDATE,''), 112), TRY_CONVERT(date, NULLIF(DATEA,''), 112),
       TRY_CONVERT(date, NULLIF(LDATE,''), 112), TRY_CONVERT(int, NULLIF(MILES,'')),
       TRY_CONVERT(smallint, NULLIF(VEH_SPEED,'')), CMPL_TYPE, NULLIF(POLICE_RPT_YN,''),
       NULLIF(MEDICAL_ATTN,''), NULLIF(REPLACE(VEHICLES_TOWED_YN, CHAR(13), ''), ''),
       STATE_OF_INCIDENT, CDESCR
FROM dbo.ComplaintsStg;
GO
SELECT COUNT(*) AS complaints_rows,
       SUM(CASE WHEN Narrative IS NOT NULL AND LEN(Narrative)>0 THEN 1 ELSE 0 END) AS has_narrative,
       MIN(DateAdded) AS earliest, MAX(DateAdded) AS latest
FROM dbo.Complaints;
GO
