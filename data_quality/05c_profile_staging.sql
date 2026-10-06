/* ==========================================================
   File    : 05c_profile_staging.sql
   Purpose : READ-ONLY profiling of the raw staging data.
             We only LOOK today. Fixing happens on Day 6.
   ========================================================== */
USE HR_Analytics;
GO

/* ---------- A. Reconciliation: did every CSV row arrive? ---------- */
SELECT x.StagingTable, x.LoadedRows, x.ExpectedRows,
       CASE WHEN x.LoadedRows = x.ExpectedRows THEN 'OK' ELSE 'MISMATCH' END AS Result
FROM (
    SELECT 'Employee_Raw' AS StagingTable, COUNT(*) AS LoadedRows, 556 AS ExpectedRows FROM stg.Employee_Raw
    UNION ALL SELECT 'SalaryHistory_Raw',     COUNT(*),   2517 FROM stg.SalaryHistory_Raw
    UNION ALL SELECT 'Attendance_Raw',        COUNT(*), 214334 FROM stg.Attendance_Raw
    UNION ALL SELECT 'PerformanceReview_Raw', COUNT(*),   1424 FROM stg.PerformanceReview_Raw
    UNION ALL SELECT 'Promotion_Raw',         COUNT(*),     51 FROM stg.Promotion_Raw
    UNION ALL SELECT 'EmployeeExit_Raw',      COUNT(*),    106 FROM stg.EmployeeExit_Raw
) AS x;

/* ---------- B. Duplicates ---------- */
SELECT EmployeeCode, COUNT(*) AS Copies
FROM stg.Employee_Raw
GROUP BY EmployeeCode
HAVING COUNT(*) > 1;

SELECT EmployeeCode, AttendanceDate, COUNT(*) AS Copies
FROM stg.Attendance_Raw
GROUP BY EmployeeCode, AttendanceDate
HAVING COUNT(*) > 1;

SELECT EmployeeCode, ReviewYear, COUNT(*) AS Copies, MIN(Rating) AS MinRating, MAX(Rating) AS MaxRating
FROM stg.PerformanceReview_Raw
GROUP BY EmployeeCode, ReviewYear
HAVING COUNT(*) > 1;

/* ---------- C. Missing values ---------- */
SELECT
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(Email)), '')       IS NULL THEN 1 ELSE 0 END) AS MissingEmail,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(ManagerCode)), '') IS NULL THEN 1 ELSE 0 END) AS MissingManager,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(Gender)), '')      IS NULL THEN 1 ELSE 0 END) AS MissingGender
FROM stg.Employee_Raw;

SELECT COUNT(*) AS MissingRating
FROM stg.PerformanceReview_Raw
WHERE NULLIF(LTRIM(RTRIM(Rating)), '') IS NULL;

SELECT COUNT(*) AS MissingSalary
FROM stg.SalaryHistory_Raw
WHERE NULLIF(LTRIM(RTRIM(BaseSalary)), '') IS NULL;

/* ---------- D. Inconsistent spellings ----------
   WHY the COLLATE trick: SQL Server's default collation is case-INSENSITIVE and
   ignores trailing spaces, so a plain GROUP BY would hide 'ENGINEERING' and
   'Engineering ' inside 'Engineering'. A binary collation + DATALENGTH exposes them. */
SELECT Gender COLLATE Latin1_General_BIN AS GenderExact,
       DATALENGTH(Gender)                AS Bytes,
       COUNT(*)                          AS Cnt
FROM stg.Employee_Raw
GROUP BY Gender COLLATE Latin1_General_BIN, DATALENGTH(Gender)
ORDER BY Cnt DESC;

SELECT DepartmentName COLLATE Latin1_General_BIN AS DepartmentExact,
       DATALENGTH(DepartmentName)                AS Bytes,
       COUNT(*)                                  AS Cnt
FROM stg.Employee_Raw
GROUP BY DepartmentName COLLATE Latin1_General_BIN, DATALENGTH(DepartmentName)
ORDER BY DepartmentExact, Bytes;

SELECT Status COLLATE Latin1_General_BIN AS StatusExact, COUNT(*) AS Cnt
FROM stg.Attendance_Raw
GROUP BY Status COLLATE Latin1_General_BIN
ORDER BY Cnt DESC;

-- Names with leading/trailing spaces (a plain <> would NOT catch trailing spaces)
SELECT COUNT(*) AS FirstNamesWithSpaces
FROM stg.Employee_Raw
WHERE DATALENGTH(FirstName) <> DATALENGTH(LTRIM(RTRIM(FirstName)));

/* ---------- E. Orphan codes (employee does not exist) ---------- */
SELECT 'Attendance' AS SourceTable, a.EmployeeCode, COUNT(*) AS RowsFound
FROM stg.Attendance_Raw AS a
LEFT JOIN (SELECT DISTINCT EmployeeCode FROM stg.Employee_Raw) AS e ON e.EmployeeCode = a.EmployeeCode
WHERE e.EmployeeCode IS NULL
GROUP BY a.EmployeeCode
UNION ALL
SELECT 'SalaryHistory', s.EmployeeCode, COUNT(*)
FROM stg.SalaryHistory_Raw AS s
LEFT JOIN (SELECT DISTINCT EmployeeCode FROM stg.Employee_Raw) AS e ON e.EmployeeCode = s.EmployeeCode
WHERE e.EmployeeCode IS NULL
GROUP BY s.EmployeeCode
UNION ALL
SELECT 'Promotion', p.EmployeeCode, COUNT(*)
FROM stg.Promotion_Raw AS p
LEFT JOIN (SELECT DISTINCT EmployeeCode FROM stg.Employee_Raw) AS e ON e.EmployeeCode = p.EmployeeCode
WHERE e.EmployeeCode IS NULL
GROUP BY p.EmployeeCode;

/* ---------- F. Values that will not convert to the right data type ---------- */
SELECT RowID, EmployeeCode, BaseSalary
FROM stg.SalaryHistory_Raw
WHERE TRY_CAST(BaseSalary AS DECIMAL(12,2)) IS NULL;

SELECT RowID, EmployeeCode, BaseSalary
FROM stg.SalaryHistory_Raw
WHERE TRY_CAST(BaseSalary AS DECIMAL(12,2)) <= 0;

SELECT TOP (10) RowID, EmployeeCode, EffectiveDate, BaseSalary
FROM stg.SalaryHistory_Raw
WHERE TRY_CAST(BaseSalary AS DECIMAL(12,2)) IS NOT NULL
ORDER BY TRY_CAST(BaseSalary AS DECIMAL(12,2)) DESC;

SELECT RowID, EmployeeCode, HireDate
FROM stg.Employee_Raw
WHERE TRY_CONVERT(DATE, HireDate, 23) IS NULL;

SELECT RowID, EmployeeCode, ReviewYear, Rating
FROM stg.PerformanceReview_Raw
WHERE TRY_CAST(Rating AS INT) IS NULL
   OR TRY_CAST(Rating AS INT) NOT BETWEEN 1 AND 5;

/* ---------- G. Business-rule violations ---------- */
SELECT RowID, EmployeeCode, ReviewerCode, ReviewYear
FROM stg.PerformanceReview_Raw
WHERE EmployeeCode = ReviewerCode;

SELECT x.RowID, x.EmployeeCode, h.HireDate, x.ExitDate
FROM stg.EmployeeExit_Raw AS x
JOIN (SELECT DISTINCT EmployeeCode, HireDate FROM stg.Employee_Raw) AS h ON h.EmployeeCode = x.EmployeeCode
WHERE TRY_CONVERT(DATE, x.ExitDate, 23) < TRY_CONVERT(DATE, h.HireDate, 23);

SELECT COUNT(*) AS RowsAfterExit
FROM stg.Attendance_Raw AS a
JOIN stg.EmployeeExit_Raw AS x ON x.EmployeeCode = a.EmployeeCode
WHERE TRY_CONVERT(DATE, a.AttendanceDate, 23) > TRY_CONVERT(DATE, x.ExitDate, 23);

SELECT COUNT(*) AS RowsBeforeHire
FROM stg.Attendance_Raw AS a
JOIN (SELECT DISTINCT EmployeeCode, HireDate FROM stg.Employee_Raw) AS h ON h.EmployeeCode = a.EmployeeCode
WHERE TRY_CONVERT(DATE, a.AttendanceDate, 23) < TRY_CONVERT(DATE, h.HireDate, 23);

SELECT SUM(CASE WHEN a.Status = 'Leave'  AND NULLIF(LTRIM(RTRIM(a.LeaveType)), '') IS NULL     THEN 1 ELSE 0 END) AS LeaveWithoutType,
       SUM(CASE WHEN a.Status <> 'Leave' AND NULLIF(LTRIM(RTRIM(a.LeaveType)), '') IS NOT NULL THEN 1 ELSE 0 END) AS NonLeaveWithType
FROM stg.Attendance_Raw AS a;
GO
