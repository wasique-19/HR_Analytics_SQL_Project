/* ==========================================================
   File    : 05b_load_staging.sql
   Purpose : Loads the 6 CSV files into the staging tables.
   BEFORE  : 1) Copy the 'raw' folder to C:\HR_Data\raw\
                (change the paths below if you use another folder)
             2) Run 05a_create_staging.sql first.
   Needs   : SQL Server 2017+ (FORMAT = 'CSV').
   Note    : BULK INSERT is read by the SQL SERVER SERVICE, not by you.
             If you see "Access is denied" (OS error 5), move the files to a
             folder every user can read, e.g. C:\HR_Data, or use the SSMS
             wizard: right-click database > Tasks > Import Flat File.
   ========================================================== */
USE HR_Analytics;
GO

/* ---------- RESET: makes this script safe to re-run ----------
   Drops the RowID column added by a previous run (the CSV has no RowID,
   so a table with an extra column makes BULK INSERT fail with Msg 7301),
   then empties each table so rows are never loaded twice. */
IF COL_LENGTH('stg.Employee_Raw',          'RowID') IS NOT NULL ALTER TABLE stg.Employee_Raw          DROP COLUMN RowID;
IF COL_LENGTH('stg.SalaryHistory_Raw',     'RowID') IS NOT NULL ALTER TABLE stg.SalaryHistory_Raw     DROP COLUMN RowID;
IF COL_LENGTH('stg.Attendance_Raw',        'RowID') IS NOT NULL ALTER TABLE stg.Attendance_Raw        DROP COLUMN RowID;
IF COL_LENGTH('stg.PerformanceReview_Raw', 'RowID') IS NOT NULL ALTER TABLE stg.PerformanceReview_Raw DROP COLUMN RowID;
IF COL_LENGTH('stg.Promotion_Raw',         'RowID') IS NOT NULL ALTER TABLE stg.Promotion_Raw         DROP COLUMN RowID;
IF COL_LENGTH('stg.EmployeeExit_Raw',      'RowID') IS NOT NULL ALTER TABLE stg.EmployeeExit_Raw      DROP COLUMN RowID;

TRUNCATE TABLE stg.Employee_Raw;
TRUNCATE TABLE stg.SalaryHistory_Raw;
TRUNCATE TABLE stg.Attendance_Raw;
TRUNCATE TABLE stg.PerformanceReview_Raw;
TRUNCATE TABLE stg.Promotion_Raw;
TRUNCATE TABLE stg.EmployeeExit_Raw;
GO

BULK INSERT stg.Employee_Raw
FROM 'C:\HR_Data\raw\employees_raw.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n',
      CODEPAGE = '65001', KEEPNULLS, TABLOCK);

BULK INSERT stg.SalaryHistory_Raw
FROM 'C:\HR_Data\raw\salary_history_raw.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n',
      CODEPAGE = '65001', KEEPNULLS, TABLOCK);

BULK INSERT stg.Attendance_Raw
FROM 'C:\HR_Data\raw\attendance_raw.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n',
      CODEPAGE = '65001', KEEPNULLS, TABLOCK);

BULK INSERT stg.PerformanceReview_Raw
FROM 'C:\HR_Data\raw\performance_reviews_raw.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n',
      CODEPAGE = '65001', KEEPNULLS, TABLOCK);

BULK INSERT stg.Promotion_Raw
FROM 'C:\HR_Data\raw\promotions_raw.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n',
      CODEPAGE = '65001', KEEPNULLS, TABLOCK);

BULK INSERT stg.EmployeeExit_Raw
FROM 'C:\HR_Data\raw\employee_exits_raw.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n',
      CODEPAGE = '65001', KEEPNULLS, TABLOCK);
GO

-- Give every raw row a permanent row number so bad rows can be traced on Day 6.
-- (Added AFTER loading: BULK INSERT cannot skip an IDENTITY column without a format file.)
ALTER TABLE stg.Employee_Raw          ADD RowID INT IDENTITY(1,1) NOT NULL;
ALTER TABLE stg.SalaryHistory_Raw     ADD RowID INT IDENTITY(1,1) NOT NULL;
ALTER TABLE stg.Attendance_Raw        ADD RowID INT IDENTITY(1,1) NOT NULL;
ALTER TABLE stg.PerformanceReview_Raw ADD RowID INT IDENTITY(1,1) NOT NULL;
ALTER TABLE stg.Promotion_Raw         ADD RowID INT IDENTITY(1,1) NOT NULL;
ALTER TABLE stg.EmployeeExit_Raw      ADD RowID INT IDENTITY(1,1) NOT NULL;
GO
