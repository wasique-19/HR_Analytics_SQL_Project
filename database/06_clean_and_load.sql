/* ==========================================================
   Project : Employee Performance & HR Analytics System
   File    : 06_clean_and_load.sql
   Purpose : Cleans the raw staging data and loads the 11 final tables.
             Every staging row ends up in EXACTLY ONE place:
               - loaded into a dbo.* table, or
               - logged in dq.RejectedRow with a reason.
   Run     : After 05a + 05b. Safe to re-run (it empties the 6 data
             tables first; reference tables are untouched).
   Policy  : FIX only when the correct value is certain
             (spelling, case, spaces, date format, commas).
             QUARANTINE when we would have to guess
             (conflicting duplicates, blank ratings, impossible dates).
   ========================================================== */
USE HR_Analytics;
GO

/* ---------- 0. Reject log (data-quality audit trail) ---------- */
IF SCHEMA_ID('dq') IS NULL EXEC('CREATE SCHEMA dq');
GO
DROP TABLE IF EXISTS dq.RejectedRow;
CREATE TABLE dq.RejectedRow (
    RejectID     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_RejectedRow PRIMARY KEY,
    SourceTable  VARCHAR(40)   NOT NULL,
    SourceRowID  INT           NOT NULL,    -- RowID in the stg.* table
    RejectReason NVARCHAR(100) NOT NULL,
    RawValue     NVARCHAR(500) NULL,        -- key fields of the rejected row
    LoggedAt     DATETIME2(0)  NOT NULL CONSTRAINT DF_RejectedRow_LoggedAt DEFAULT SYSDATETIME()
);
GO

/* ---------- 1. Reset the 6 data tables (children first) ---------- */
DELETE FROM dbo.EmployeeExit;
DELETE FROM dbo.Promotion;
DELETE FROM dbo.PerformanceReview;
DELETE FROM dbo.Attendance;
DELETE FROM dbo.SalaryHistory;
UPDATE dbo.Employee SET ManagerID = NULL;   -- break the self-reference first
DELETE FROM dbo.Employee;

-- Restart IDs at 1. RESEED 0 is only correct if the table has been used before:
-- on a never-used table SQL Server would give the first row ID 0, so we check last_value first.
IF EXISTS (SELECT 1 FROM sys.identity_columns WHERE object_id = OBJECT_ID('dbo.EmployeeExit') AND last_value IS NOT NULL)
    DBCC CHECKIDENT ('dbo.EmployeeExit', RESEED, 0) WITH NO_INFOMSGS;
IF EXISTS (SELECT 1 FROM sys.identity_columns WHERE object_id = OBJECT_ID('dbo.Promotion') AND last_value IS NOT NULL)
    DBCC CHECKIDENT ('dbo.Promotion', RESEED, 0) WITH NO_INFOMSGS;
IF EXISTS (SELECT 1 FROM sys.identity_columns WHERE object_id = OBJECT_ID('dbo.PerformanceReview') AND last_value IS NOT NULL)
    DBCC CHECKIDENT ('dbo.PerformanceReview', RESEED, 0) WITH NO_INFOMSGS;
IF EXISTS (SELECT 1 FROM sys.identity_columns WHERE object_id = OBJECT_ID('dbo.Attendance') AND last_value IS NOT NULL)
    DBCC CHECKIDENT ('dbo.Attendance', RESEED, 0) WITH NO_INFOMSGS;
IF EXISTS (SELECT 1 FROM sys.identity_columns WHERE object_id = OBJECT_ID('dbo.SalaryHistory') AND last_value IS NOT NULL)
    DBCC CHECKIDENT ('dbo.SalaryHistory', RESEED, 0) WITH NO_INFOMSGS;
IF EXISTS (SELECT 1 FROM sys.identity_columns WHERE object_id = OBJECT_ID('dbo.Employee') AND last_value IS NOT NULL)
    DBCC CHECKIDENT ('dbo.Employee', RESEED, 0) WITH NO_INFOMSGS;
GO

/* ==========================================================
   2. EMPLOYEE
   Fixes : trim, case, gender spellings, dd/mm/yyyy dates, missing email (imputed)
   Rejects: duplicates, unparseable values, unknown department/job/city
   ========================================================== */
DROP TABLE IF EXISTS #EmpClean;

SELECT s.RowID,
       UPPER(LTRIM(RTRIM(s.EmployeeCode)))              AS EmployeeCode,
       LTRIM(RTRIM(s.FirstName))                        AS FirstName,
       LTRIM(RTRIM(s.LastName))                         AS LastName,
       CASE UPPER(LEFT(LTRIM(RTRIM(s.Gender)), 1))      -- 'Male','m',' M' -> M ; 'female','F ' -> F
            WHEN 'M' THEN 'M' WHEN 'F' THEN 'F' WHEN 'O' THEN 'O' END AS Gender,
       TRY_CONVERT(DATE, LTRIM(RTRIM(s.DateOfBirth)), 23) AS DateOfBirth,
       NULLIF(LOWER(LTRIM(RTRIM(s.Email))), '')         AS Email,
       COALESCE(TRY_CONVERT(DATE, LTRIM(RTRIM(s.HireDate)), 23),    -- yyyy-mm-dd
                TRY_CONVERT(DATE, LTRIM(RTRIM(s.HireDate)), 103))   -- dd/mm/yyyy
                                                        AS HireDate,
       NULLIF(LTRIM(RTRIM(s.EmploymentType)), '')       AS EmploymentType,
       d.DepartmentID, j.JobRoleID, l.LocationID,
       NULLIF(UPPER(LTRIM(RTRIM(s.ManagerCode))), '')   AS ManagerCode,
       ROW_NUMBER() OVER (PARTITION BY UPPER(LTRIM(RTRIM(s.EmployeeCode)))
                          ORDER BY s.RowID)             AS rn,
       CAST(NULL AS NVARCHAR(100))                      AS RejectReason,
       CONCAT(s.EmployeeCode, ' | ', s.FirstName, ' ', s.LastName, ' | hire ', s.HireDate) AS RawText
INTO #EmpClean
FROM stg.Employee_Raw AS s
LEFT JOIN dbo.Department AS d ON d.DepartmentName = LTRIM(RTRIM(s.DepartmentName))
LEFT JOIN dbo.JobRole    AS j ON j.DepartmentID = d.DepartmentID AND j.JobTitle = LTRIM(RTRIM(s.JobTitle))
LEFT JOIN dbo.Location   AS l ON l.City = LTRIM(RTRIM(s.City));
GO

UPDATE #EmpClean
SET RejectReason =
    CASE WHEN rn > 1                                          THEN 'Duplicate row'
         WHEN Gender IS NULL                                  THEN 'Invalid gender'
         WHEN DateOfBirth IS NULL                             THEN 'Invalid date of birth'
         WHEN HireDate IS NULL                                THEN 'Invalid hire date'
         WHEN ISNULL(FirstName, '') = '' OR ISNULL(LastName, '') = '' THEN 'Missing name'
         WHEN DepartmentID IS NULL OR JobRoleID IS NULL OR LocationID IS NULL
                                                              THEN 'Unknown department, job title or city'
         WHEN HireDate < '2010-01-01'                         THEN 'Hire date before 2010'
         WHEN HireDate < DATEADD(YEAR, 18, DateOfBirth)       THEN 'Under 18 at hire'
         WHEN EmploymentType IS NULL
           OR EmploymentType NOT IN ('Full-Time','Contract','Intern') THEN 'Invalid employment type'
    END;

-- Missing e-mail: build a unique placeholder (UQ_Employee_Email + NOT NULL need a value)
UPDATE #EmpClean
SET Email = LOWER(REPLACE(FirstName + '.' + LastName + '.' + EmployeeCode, ' ', '')) + '@northpeak.example'
WHERE Email IS NULL AND RejectReason IS NULL;
PRINT 'Employee e-mails imputed: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

INSERT INTO dbo.Employee
    (EmployeeCode, FirstName, LastName, Gender, DateOfBirth, Email, HireDate,
     EmploymentType, DepartmentID, JobRoleID, LocationID, ManagerID)
SELECT EmployeeCode, FirstName, LastName, Gender, DateOfBirth, Email, HireDate,
       EmploymentType, DepartmentID, JobRoleID, LocationID, NULL
FROM #EmpClean
WHERE RejectReason IS NULL
ORDER BY EmployeeCode;                      -- so EmployeeID follows EmployeeCode order

-- Managers: a second pass (an INSERT...SELECT cannot see its own new rows - the Day 4 lesson)
UPDATE e
SET e.ManagerID = m.EmployeeID
FROM dbo.Employee AS e
JOIN #EmpClean    AS c ON c.EmployeeCode = e.EmployeeCode AND c.RejectReason IS NULL
JOIN dbo.Employee AS m ON m.EmployeeCode = c.ManagerCode;

INSERT INTO dq.RejectedRow (SourceTable, SourceRowID, RejectReason, RawValue)
SELECT 'Employee_Raw', RowID, RejectReason, RawText FROM #EmpClean WHERE RejectReason IS NOT NULL;
GO

/* ==========================================================
   3. EMPLOYEE EXIT  (loaded before attendance: attendance is checked against exit dates)
   ========================================================== */
DROP TABLE IF EXISTS #ExitClean;

SELECT x.RowID,
       e.EmployeeID, e.HireDate,
       TRY_CONVERT(DATE, LTRIM(RTRIM(x.ExitDate)), 23) AS ExitDate,
       r.ExitReasonID,
       NULLIF(LTRIM(RTRIM(x.Notes)), '')               AS Notes,
       ROW_NUMBER() OVER (PARTITION BY UPPER(LTRIM(RTRIM(x.EmployeeCode))) ORDER BY x.RowID) AS rn,
       CAST(NULL AS NVARCHAR(100))                     AS RejectReason,
       CONCAT(x.EmployeeCode, ' | exit ', x.ExitDate, ' | ', x.ExitReason) AS RawText
INTO #ExitClean
FROM stg.EmployeeExit_Raw AS x
LEFT JOIN dbo.Employee   AS e ON e.EmployeeCode = UPPER(LTRIM(RTRIM(x.EmployeeCode)))
LEFT JOIN dbo.ExitReason AS r ON r.ReasonName   = LTRIM(RTRIM(x.ExitReason));
GO

UPDATE #ExitClean
SET RejectReason =
    CASE WHEN EmployeeID   IS NULL     THEN 'Unknown employee'
         WHEN ExitDate     IS NULL     THEN 'Invalid exit date'
         WHEN ExitReasonID IS NULL     THEN 'Unknown exit reason'
         WHEN ExitDate < HireDate      THEN 'Exit date before hire date'
         WHEN rn > 1                   THEN 'Duplicate exit for employee'
    END;

INSERT INTO dbo.EmployeeExit (EmployeeID, ExitDate, ExitReasonID, Notes)
SELECT EmployeeID, ExitDate, ExitReasonID, Notes
FROM #ExitClean WHERE RejectReason IS NULL
ORDER BY EmployeeID;

INSERT INTO dq.RejectedRow (SourceTable, SourceRowID, RejectReason, RawValue)
SELECT 'EmployeeExit_Raw', RowID, RejectReason, RawText FROM #ExitClean WHERE RejectReason IS NOT NULL;
GO

/* ==========================================================
   4. SALARY HISTORY
   Fixes : '8,50,000' -> 850000
   Rejects: blank/zero/negative, outliers, orphans, duplicates
   ========================================================== */
DROP TABLE IF EXISTS #SalClean;

SELECT s.RowID,
       e.EmployeeID, e.HireDate, j.MaxSalary AS RoleMax,
       TRY_CONVERT(DATE, LTRIM(RTRIM(s.EffectiveDate)), 23) AS EffectiveDate,
       TRY_CAST(NULLIF(REPLACE(LTRIM(RTRIM(s.BaseSalary)), ',', ''), '') AS DECIMAL(12,2)) AS BaseSalary,
       LTRIM(RTRIM(s.ChangeReason))                          AS ChangeReason,
       CAST(NULL AS NVARCHAR(100))                           AS RejectReason,
       CONCAT(s.EmployeeCode, ' | ', s.EffectiveDate, ' | ', s.BaseSalary) AS RawText
INTO #SalClean
FROM stg.SalaryHistory_Raw AS s
LEFT JOIN dbo.Employee AS e ON e.EmployeeCode = UPPER(LTRIM(RTRIM(s.EmployeeCode)))
LEFT JOIN dbo.JobRole  AS j ON j.JobRoleID = e.JobRoleID;
GO

UPDATE #SalClean
SET RejectReason =
    CASE WHEN EmployeeID IS NULL                         THEN 'Unknown employee'
         WHEN BaseSalary IS NULL                         THEN 'Missing or invalid salary'
         WHEN BaseSalary <= 0                            THEN 'Non-positive salary'
         WHEN EffectiveDate IS NULL                      THEN 'Invalid effective date'
         WHEN ChangeReason NOT IN ('Hire','Annual Increment','Promotion','Correction')
                                                         THEN 'Invalid change reason'
         WHEN EffectiveDate < HireDate                   THEN 'Effective date before hire date'
    END;

-- Outliers: more than 2x the role's maximum band, or more than 5x the employee's own lowest salary.
-- (A legitimate employee never grows more than ~3x between first and last salary.)
;WITH m AS (
    SELECT RowID,
           MIN(CASE WHEN RejectReason IS NULL THEN BaseSalary END) OVER (PARTITION BY EmployeeID) AS MinOk
    FROM #SalClean
)
UPDATE s
SET RejectReason = 'Salary outlier (>2x band max or >5x own minimum)'
FROM #SalClean AS s
JOIN m ON m.RowID = s.RowID
WHERE s.RejectReason IS NULL
  AND (s.BaseSalary > 2 * s.RoleMax OR s.BaseSalary > 5 * m.MinOk);

;WITH d AS (
    SELECT RowID, ROW_NUMBER() OVER (PARTITION BY EmployeeID, EffectiveDate ORDER BY RowID) AS rn
    FROM #SalClean WHERE RejectReason IS NULL
)
UPDATE s
SET RejectReason = 'Duplicate (employee, effective date)'
FROM #SalClean AS s JOIN d ON d.RowID = s.RowID
WHERE d.rn > 1;

INSERT INTO dbo.SalaryHistory (EmployeeID, EffectiveDate, BaseSalary, ChangeReason)
SELECT EmployeeID, EffectiveDate, BaseSalary, ChangeReason
FROM #SalClean WHERE RejectReason IS NULL
ORDER BY EmployeeID, EffectiveDate;

INSERT INTO dq.RejectedRow (SourceTable, SourceRowID, RejectReason, RawValue)
SELECT 'SalaryHistory_Raw', RowID, RejectReason, RawText FROM #SalClean WHERE RejectReason IS NOT NULL;
GO

/* ==========================================================
   5. ATTENDANCE (the big one: ~214,000 rows)
   Fixes : status spellings ('present','PRESENT','P')
   Rejects: orphans, leave-rule violations, before hire, after exit, duplicates
   ========================================================== */
DROP TABLE IF EXISTS #AttClean;

SELECT a.RowID,
       e.EmployeeID, e.HireDate, x.ExitDate,
       TRY_CONVERT(DATE, LTRIM(RTRIM(a.AttendanceDate)), 23) AS AttendanceDate,
       CASE UPPER(LTRIM(RTRIM(a.Status)))
            WHEN 'PRESENT' THEN 'Present' WHEN 'P' THEN 'Present'
            WHEN 'ABSENT'  THEN 'Absent'  WHEN 'A' THEN 'Absent'
            WHEN 'LEAVE'   THEN 'Leave'   WHEN 'L' THEN 'Leave'
            WHEN 'WFH'     THEN 'WFH' END                     AS Status,
       NULLIF(LTRIM(RTRIM(a.LeaveType)), '')                  AS LeaveRaw,
       lt.LeaveTypeID,
       CAST(NULL AS NVARCHAR(100))                            AS RejectReason,
       CONCAT(a.EmployeeCode, ' | ', a.AttendanceDate, ' | ', a.Status, ' | ', a.LeaveType) AS RawText
INTO #AttClean
FROM stg.Attendance_Raw AS a
LEFT JOIN dbo.Employee     AS e  ON e.EmployeeCode = UPPER(LTRIM(RTRIM(a.EmployeeCode)))
LEFT JOIN dbo.EmployeeExit AS x  ON x.EmployeeID   = e.EmployeeID
LEFT JOIN dbo.LeaveType    AS lt ON lt.LeaveTypeName = NULLIF(LTRIM(RTRIM(a.LeaveType)), '');
GO

UPDATE #AttClean
SET RejectReason =
    CASE WHEN EmployeeID IS NULL                          THEN 'Unknown employee'
         WHEN AttendanceDate IS NULL                      THEN 'Invalid date'
         WHEN Status IS NULL                              THEN 'Invalid status'
         WHEN Status = 'Leave' AND LeaveRaw IS NULL       THEN 'Leave without leave type'
         WHEN Status = 'Leave' AND LeaveTypeID IS NULL    THEN 'Invalid leave type'
         WHEN Status <> 'Leave' AND LeaveRaw IS NOT NULL  THEN 'Leave type on non-leave status'
         WHEN AttendanceDate < HireDate                   THEN 'Before hire date'
         WHEN ExitDate IS NOT NULL AND AttendanceDate > ExitDate THEN 'After exit date'
    END;

;WITH d AS (
    SELECT RowID, ROW_NUMBER() OVER (PARTITION BY EmployeeID, AttendanceDate ORDER BY RowID) AS rn
    FROM #AttClean WHERE RejectReason IS NULL
)
UPDATE a
SET RejectReason = 'Duplicate (employee, date)'
FROM #AttClean AS a JOIN d ON d.RowID = a.RowID
WHERE d.rn > 1;

INSERT INTO dbo.Attendance (EmployeeID, AttendanceDate, Status, LeaveTypeID)
SELECT EmployeeID, AttendanceDate, Status, LeaveTypeID
FROM #AttClean WHERE RejectReason IS NULL
ORDER BY EmployeeID, AttendanceDate;

INSERT INTO dq.RejectedRow (SourceTable, SourceRowID, RejectReason, RawValue)
SELECT 'Attendance_Raw', RowID, RejectReason, RawText FROM #AttClean WHERE RejectReason IS NOT NULL;
GO

/* ==========================================================
   6. PERFORMANCE REVIEWS
   Rejects: orphans, blank/out-of-range ratings, self-reviews, conflicting duplicates
   ========================================================== */
DROP TABLE IF EXISTS #RevClean;

SELECT v.RowID,
       e.EmployeeID, rv.EmployeeID AS ReviewerID, e.HireDate, x.ExitDate,
       TRY_CAST(NULLIF(LTRIM(RTRIM(v.ReviewYear)), '') AS INT) AS ReviewYear,
       TRY_CONVERT(DATE, LTRIM(RTRIM(v.ReviewDate)), 23)        AS ReviewDate,
       TRY_CAST(NULLIF(LTRIM(RTRIM(v.Rating)), '') AS INT)      AS Rating,
       CAST(NULL AS NVARCHAR(100))                              AS RejectReason,
       CONCAT(v.EmployeeCode, ' | ', v.ReviewYear, ' | rating ', v.Rating) AS RawText
INTO #RevClean
FROM stg.PerformanceReview_Raw AS v
LEFT JOIN dbo.Employee     AS e  ON e.EmployeeCode  = UPPER(LTRIM(RTRIM(v.EmployeeCode)))
LEFT JOIN dbo.Employee     AS rv ON rv.EmployeeCode = UPPER(LTRIM(RTRIM(v.ReviewerCode)))
LEFT JOIN dbo.EmployeeExit AS x  ON x.EmployeeID    = e.EmployeeID;
GO

UPDATE #RevClean
SET RejectReason =
    CASE WHEN EmployeeID IS NULL                          THEN 'Unknown employee'
         WHEN ReviewerID IS NULL                          THEN 'Unknown reviewer'
         WHEN ReviewYear IS NULL OR ReviewDate IS NULL    THEN 'Invalid year or date'
         WHEN Rating IS NULL                              THEN 'Missing rating'
         WHEN Rating NOT BETWEEN 1 AND 5                  THEN 'Rating out of range'
         WHEN EmployeeID = ReviewerID                     THEN 'Self-review'
         WHEN ReviewYear <> YEAR(ReviewDate)              THEN 'Year does not match review date'
         WHEN ReviewDate < HireDate                       THEN 'Before hire date'
         WHEN ExitDate IS NOT NULL AND ReviewDate > ExitDate THEN 'After exit date'
    END;

-- Same employee + year more than once: identical ratings -> keep first; different ratings -> keep NONE
-- (we cannot know which is true, so HR must resolve it at the source)
;WITH g AS (
    SELECT RowID,
           ROW_NUMBER() OVER (PARTITION BY EmployeeID, ReviewYear ORDER BY RowID) AS rn,
           COUNT(*)    OVER (PARTITION BY EmployeeID, ReviewYear)                 AS cnt,
           MIN(Rating) OVER (PARTITION BY EmployeeID, ReviewYear)                 AS minR,
           MAX(Rating) OVER (PARTITION BY EmployeeID, ReviewYear)                 AS maxR
    FROM #RevClean WHERE RejectReason IS NULL
)
UPDATE s
SET RejectReason = CASE WHEN g.minR <> g.maxR
                        THEN 'Conflicting duplicate (same employee-year, different ratings)'
                        ELSE 'Duplicate (employee, year)' END
FROM #RevClean AS s JOIN g ON g.RowID = s.RowID
WHERE g.cnt > 1 AND (g.minR <> g.maxR OR g.rn > 1);

INSERT INTO dbo.PerformanceReview (EmployeeID, ReviewerID, ReviewYear, ReviewDate, Rating)
SELECT EmployeeID, ReviewerID, CAST(ReviewYear AS SMALLINT), ReviewDate, CAST(Rating AS TINYINT)
FROM #RevClean WHERE RejectReason IS NULL
ORDER BY EmployeeID, ReviewYear;

INSERT INTO dq.RejectedRow (SourceTable, SourceRowID, RejectReason, RawValue)
SELECT 'PerformanceReview_Raw', RowID, RejectReason, RawText FROM #RevClean WHERE RejectReason IS NOT NULL;
GO

/* ==========================================================
   7. PROMOTIONS  (department + title text -> role IDs)
   ========================================================== */
DROP TABLE IF EXISTS #PromoClean;

SELECT p.RowID,
       e.EmployeeID, e.HireDate, x.ExitDate,
       TRY_CONVERT(DATE, LTRIM(RTRIM(p.PromotionDate)), 23) AS PromotionDate,
       NULLIF(LTRIM(RTRIM(p.MovementType)), '')             AS MovementType,
       oj.JobRoleID AS OldJobRoleID, nj.JobRoleID AS NewJobRoleID,
       od.DepartmentID AS OldDepartmentID, nd.DepartmentID AS NewDepartmentID,
       CAST(NULL AS NVARCHAR(100))                          AS RejectReason,
       CONCAT(p.EmployeeCode, ' | ', p.PromotionDate, ' | ', p.OldJobTitle, ' -> ', p.NewJobTitle) AS RawText
INTO #PromoClean
FROM stg.Promotion_Raw AS p
LEFT JOIN dbo.Employee     AS e  ON e.EmployeeCode = UPPER(LTRIM(RTRIM(p.EmployeeCode)))
LEFT JOIN dbo.EmployeeExit AS x  ON x.EmployeeID   = e.EmployeeID
LEFT JOIN dbo.Department   AS od ON od.DepartmentName = LTRIM(RTRIM(p.OldDepartment))
LEFT JOIN dbo.Department   AS nd ON nd.DepartmentName = LTRIM(RTRIM(p.NewDepartment))
LEFT JOIN dbo.JobRole      AS oj ON oj.DepartmentID = od.DepartmentID AND oj.JobTitle = LTRIM(RTRIM(p.OldJobTitle))
LEFT JOIN dbo.JobRole      AS nj ON nj.DepartmentID = nd.DepartmentID AND nj.JobTitle = LTRIM(RTRIM(p.NewJobTitle));
GO

UPDATE #PromoClean
SET RejectReason =
    CASE WHEN EmployeeID IS NULL                           THEN 'Unknown employee'
         WHEN PromotionDate IS NULL                        THEN 'Invalid promotion date'
         WHEN MovementType IS NULL
           OR MovementType NOT IN ('Promotion','Lateral Transfer') THEN 'Invalid movement type'
         WHEN OldJobRoleID IS NULL OR NewJobRoleID IS NULL THEN 'Unknown job role'
         WHEN OldJobRoleID = NewJobRoleID AND OldDepartmentID = NewDepartmentID THEN 'No change in role or department'
         WHEN PromotionDate < HireDate                     THEN 'Before hire date'
         WHEN ExitDate IS NOT NULL AND PromotionDate > ExitDate THEN 'After exit date'
    END;

INSERT INTO dbo.Promotion
    (EmployeeID, PromotionDate, MovementType, OldJobRoleID, NewJobRoleID, OldDepartmentID, NewDepartmentID)
SELECT EmployeeID, PromotionDate, MovementType, OldJobRoleID, NewJobRoleID, OldDepartmentID, NewDepartmentID
FROM #PromoClean WHERE RejectReason IS NULL
ORDER BY EmployeeID, PromotionDate;

INSERT INTO dq.RejectedRow (SourceTable, SourceRowID, RejectReason, RawValue)
SELECT 'Promotion_Raw', RowID, RejectReason, RawText FROM #PromoClean WHERE RejectReason IS NOT NULL;
GO

/* ---------- 8. Quick summary (full checks are in data_quality/validation_checks.sql) ---------- */
SELECT SourceTable, RejectReason, COUNT(*) AS RowsRejected
FROM dq.RejectedRow
GROUP BY SourceTable, RejectReason
ORDER BY SourceTable, RowsRejected DESC;
GO
