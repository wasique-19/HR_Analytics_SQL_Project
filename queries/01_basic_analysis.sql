/* ==========================================================
   Project : Employee Performance & HR Analytics System
   File    : queries/01_basic_analysis.sql      (DAY 7)
   Purpose : Basic SQL analysis - SELECT, WHERE, ORDER BY, GROUP BY,
             HAVING, DISTINCT, CASE, aggregates, date/string/NULL handling.
   Needs   : Day 6 finished (06_clean_and_load.sql has been run).
   Run     : Best: highlight ONE query (include its DECLARE line, if it has one) and press F5.
             Running the whole file also works (GO separates the batches that use
             @AsOfDate) but returns ~35 result sets.

   ANALYSIS DATE: the data ends on 2025-12-31, so every "as of" calculation
   uses a FIXED date, never GETDATE(). Otherwise tenure and "last 12 months"
   would change every day you run the query.

   EXPECTED values in comments were calculated on the same cleaned dataset
   (550 employees). A T-SQL run on a real SQL Server was not possible here,
   so if YOUR result differs, that is a finding: investigate it, do not
   force it to match.
   ========================================================== */
USE HR_Analytics;
GO

/* ==========================================================
   SECTION A - SELECT, WHERE, ORDER BY, TOP, DISTINCT
   ========================================================== */

-- A1. WHERE with AND / IN / comparison operators  (business: who are our newer engineers?)
--     Active, Engineering, Bengaluru or Pune, hired since 2024, not an intern.
SELECT TOP (5)
       e.EmployeeCode,
       e.FirstName,
       e.LastName,
       j.JobTitle,
       l.City,
       e.HireDate
FROM dbo.Employee      AS e
JOIN dbo.Department    AS d ON d.DepartmentID = e.DepartmentID
JOIN dbo.JobRole       AS j ON j.JobRoleID    = e.JobRoleID
JOIN dbo.Location      AS l ON l.LocationID   = e.LocationID
LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
WHERE x.EmployeeID IS NULL                       -- no exit row = still active
  AND d.DepartmentName = 'Engineering'
  AND l.City IN ('Bengaluru', 'Pune')
  AND e.HireDate >= '2024-01-01'
  AND e.EmploymentType <> 'Intern'
ORDER BY e.HireDate DESC, e.EmployeeCode;        -- tie-break so the order is always the same
-- EXPECTED (5 rows shown; 11 employees match in total):
--   NP0151 Neha Chopra       Senior Software Engineer Bengaluru 2025-08-31
--   NP0070 Kunal Reddy       Senior Software Engineer Bengaluru 2025-06-22
--   NP0037 Siddharth Mishra  Senior Software Engineer Bengaluru 2025-05-20
--   NP0081 Ashish Sharma     Software Engineer        Bengaluru 2025-03-05
--   NP0112 Ashish Pandey     Senior Software Engineer Pune      2024-11-28

-- A2. DISTINCT: what values exist?
SELECT DISTINCT EmploymentType FROM dbo.Employee ORDER BY EmploymentType;
-- EXPECTED: Contract, Full-Time, Intern

SELECT COUNT(DISTINCT JobRoleID)    AS JobRolesInUse,
       COUNT(DISTINCT DepartmentID) AS DepartmentsInUse
FROM dbo.Employee;
-- EXPECTED: 41 | 8      (all 41 job roles are held by at least one person)

-- A3. Employment type mix (all 550 people ever employed)
SELECT EmploymentType, COUNT(*) AS Employees
FROM dbo.Employee
GROUP BY EmploymentType
ORDER BY Employees DESC;
-- EXPECTED: Full-Time 467 | Contract 51 | Intern 32

/* ==========================================================
   SECTION B - GROUP BY + aggregates (workforce questions, Day 1 Q1-Q3)
   ========================================================== */

-- B1. Active vs exited (Day 1 Q1).  CASE inside GROUP BY must be repeated:
--     T-SQL does not allow a column ALIAS in GROUP BY (it does in ORDER BY).
SELECT CASE WHEN x.EmployeeID IS NULL THEN 'Active' ELSE 'Exited' END AS EmployeeStatus,
       COUNT(*) AS Employees
FROM dbo.Employee AS e
LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
GROUP BY CASE WHEN x.EmployeeID IS NULL THEN 'Active' ELSE 'Exited' END
ORDER BY Employees DESC;
-- EXPECTED: Active 446 | Exited 104     (the 2 quarantined exit records are counted as Active - Day 6 HR follow-up)

-- B2. Active headcount by department (Day 1 Q2)
SELECT d.DepartmentName, COUNT(*) AS ActiveHeadcount
FROM dbo.Employee AS e
JOIN dbo.Department AS d ON d.DepartmentID = e.DepartmentID
LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
WHERE x.EmployeeID IS NULL
GROUP BY d.DepartmentName
ORDER BY ActiveHeadcount DESC, d.DepartmentName;
-- EXPECTED: Engineering 122 | Sales 79 | Customer Support 65 | Operations 60 | Marketing 34 | Finance 31 | IT 31 | HR 24   (sum 446)

-- B3. Active headcount by gender, with % of total.
--     SUM(COUNT(*)) OVER () = "the total of all groups" (a Day 9 window function, previewed here).
SELECT e.Gender,
       COUNT(*) AS Employees,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,1)) AS Pct
FROM dbo.Employee AS e
LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
WHERE x.EmployeeID IS NULL
GROUP BY e.Gender
ORDER BY Employees DESC;
-- EXPECTED: M 267 (59.9) | F 172 (38.6) | O 7 (1.6)

-- B4. Active headcount by city
SELECT l.City, COUNT(*) AS ActiveHeadcount
FROM dbo.Employee AS e
JOIN dbo.Location AS l ON l.LocationID = e.LocationID
LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
WHERE x.EmployeeID IS NULL
GROUP BY l.City
ORDER BY ActiveHeadcount DESC;
-- EXPECTED: Bengaluru 137 | Mumbai 80 | Hyderabad 78 | Pune 76 | Delhi 51 | Lucknow 24

-- B5. Hires per year (date function YEAR)
SELECT YEAR(HireDate) AS HireYear, COUNT(*) AS Hires
FROM dbo.Employee
WHERE HireDate >= '2017-01-01'
GROUP BY YEAR(HireDate)
ORDER BY HireYear;
-- EXPECTED: 2017 45 | 2018 33 | 2019 52 | 2020 49 | 2021 30 | 2022 81 | 2023 67 | 2024 77 | 2025 62

-- B6. Average tenure of ACTIVE employees by department (Day 1 Q3)
--     Use DATEDIFF(DAY, ...) / 365.25.  DATEDIFF(YEAR, ...) only counts calendar-year
--     boundaries crossed, so 2025-12-31 -> 2026-01-01 is "1 year" (see query F1).
GO
DECLARE @AsOfDate DATE = '2025-12-31';   -- GO above = fresh batch, so this name is never declared twice
SELECT d.DepartmentName,
       CAST(AVG(DATEDIFF(DAY, e.HireDate, @AsOfDate) / 365.25) AS DECIMAL(4,1)) AS AvgTenureYears
FROM dbo.Employee AS e
JOIN dbo.Department AS d ON d.DepartmentID = e.DepartmentID
LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
WHERE x.EmployeeID IS NULL
GROUP BY d.DepartmentName
ORDER BY AvgTenureYears DESC, d.DepartmentName;
-- EXPECTED: IT 5.5 | Customer Support 5.2 | HR 5.2 | Marketing 5.2 | Finance 4.6 | Engineering 4.5 | Sales 4.5 | Operations 4.4

/* ==========================================================
   SECTION C - CASE (turn numbers into business categories)
   ========================================================== */

-- C1. Tenure bands of active employees
GO
DECLARE @AsOfDate DATE = '2025-12-31';   -- GO above = fresh batch, so this name is never declared twice
SELECT CASE WHEN DATEDIFF(DAY, e.HireDate, @AsOfDate) / 365.25 < 1 THEN '1) Under 1 year'
            WHEN DATEDIFF(DAY, e.HireDate, @AsOfDate) / 365.25 < 3 THEN '2) 1 to under 3 years'
            WHEN DATEDIFF(DAY, e.HireDate, @AsOfDate) / 365.25 < 5 THEN '3) 3 to under 5 years'
            ELSE '4) 5+ years' END AS TenureBand,
       COUNT(*) AS Employees
FROM dbo.Employee AS e
LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
WHERE x.EmployeeID IS NULL
GROUP BY CASE WHEN DATEDIFF(DAY, e.HireDate, @AsOfDate) / 365.25 < 1 THEN '1) Under 1 year'
              WHEN DATEDIFF(DAY, e.HireDate, @AsOfDate) / 365.25 < 3 THEN '2) 1 to under 3 years'
              WHEN DATEDIFF(DAY, e.HireDate, @AsOfDate) / 365.25 < 5 THEN '3) 3 to under 5 years'
              ELSE '4) 5+ years' END
ORDER BY TenureBand;
-- EXPECTED: Under 1 year 54 | 1-3 years 119 | 3-5 years 81 | 5+ years 192   (sum 446)

-- C2. Performance bands, review year 2025 (Day 1 Q5 preview)
SELECT CASE WHEN r.Rating >= 4 THEN 'High performer (4-5)'
            WHEN r.Rating = 3  THEN 'Meets expectations (3)'
            ELSE 'Needs improvement (1-2)' END AS PerformanceBand,
       COUNT(*) AS Reviews,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,1)) AS Pct
FROM dbo.PerformanceReview AS r
WHERE r.ReviewYear = 2025
GROUP BY CASE WHEN r.Rating >= 4 THEN 'High performer (4-5)'
              WHEN r.Rating = 3  THEN 'Meets expectations (3)'
              ELSE 'Needs improvement (1-2)' END
ORDER BY MIN(r.Rating) DESC;
-- EXPECTED: High 155 (37.4%) | Meets 155 (37.4%) | Needs improvement 104 (25.1%)   (414 reviews)

/* ==========================================================
   SECTION D - Performance and HAVING (Day 1 Q4)
   ========================================================== */

-- D1. Average rating by department, 2025.  THE AVG TRAP:
--     Rating is TINYINT, and AVG() of an integer type returns an INTEGER (it truncates).
--     AvgRating_Wrong is shown beside the right answer so you can see the damage.
SELECT d.DepartmentName,
       COUNT(*)                                                         AS Reviews,
       AVG(r.Rating)                                                    AS AvgRating_Wrong,
       CAST(AVG(CAST(r.Rating AS DECIMAL(5,2))) AS DECIMAL(4,2))        AS AvgRating_Correct
FROM dbo.PerformanceReview AS r
JOIN dbo.Employee   AS e ON e.EmployeeID   = r.EmployeeID
JOIN dbo.Department AS d ON d.DepartmentID = e.DepartmentID
WHERE r.ReviewYear = 2025
GROUP BY d.DepartmentName
ORDER BY AvgRating_Correct DESC, d.DepartmentName;
-- EXPECTED (Correct column): Sales 3.28 | Engineering 3.25 | Customer Support 3.21 | Marketing 3.15 |
--                            Finance 3.11 | Operations 3.07 | HR 3.05 | IT 2.89
-- AvgRating_Wrong shows 3 for seven departments and 2 for IT (integer truncation of the values above).

-- D2. HAVING filters GROUPS (after aggregation); WHERE filters ROWS (before).
--     Which departments averaged below 3.10 in 2025?
SELECT d.DepartmentName,
       CAST(AVG(CAST(r.Rating AS DECIMAL(5,2))) AS DECIMAL(4,2)) AS AvgRating
FROM dbo.PerformanceReview AS r
JOIN dbo.Employee   AS e ON e.EmployeeID   = r.EmployeeID
JOIN dbo.Department AS d ON d.DepartmentID = e.DepartmentID
WHERE r.ReviewYear = 2025
GROUP BY d.DepartmentName
HAVING AVG(CAST(r.Rating AS DECIMAL(5,2))) < 3.10
ORDER BY AvgRating;
-- EXPECTED: IT 2.89 | HR 3.05 | Operations 3.07

/* ==========================================================
   SECTION E - Attendance (Day 1 Q8-Q9)
   KPI DECISION (write it in kpi_definitions.md):
   Absenteeism % = Absent rows / ALL attendance rows.
   Approved Leave and WFH are NOT absences. Leave % is reported separately.
   ========================================================== */

-- E1. Absenteeism by department, calendar 2025.
--     The date filter is written as >= start AND < next-start (not YEAR(col) = 2025)
--     so SQL Server can use an index on AttendanceDate (Day 11).
SELECT d.DepartmentName,
       COUNT(*) AS AttendanceRows,
       SUM(CASE WHEN a.Status = 'Absent' THEN 1 ELSE 0 END) AS AbsentDays,
       CAST(100.0 * SUM(CASE WHEN a.Status = 'Absent' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS AbsenteeismPct
FROM dbo.Attendance AS a
JOIN dbo.Employee   AS e ON e.EmployeeID   = a.EmployeeID
JOIN dbo.Department AS d ON d.DepartmentID = e.DepartmentID
WHERE a.AttendanceDate >= '2025-01-01' AND a.AttendanceDate < '2026-01-01'
GROUP BY d.DepartmentName
ORDER BY AbsenteeismPct DESC, d.DepartmentName;
-- EXPECTED: Marketing 3.71 | Finance 3.39 | Operations 3.38 | HR 3.25 | Engineering 3.11 |
--           Customer Support 2.93 | Sales 2.93 | IT 2.81
-- Total rows 2025: Present 88,968 | WFH 12,375 | Leave 6,856 | Absent 3,507

-- E2. Absence and leave by month, 2025
SELECT MONTH(a.AttendanceDate)                      AS MonthNo,
       DATENAME(MONTH, MIN(a.AttendanceDate))       AS MonthName,
       COUNT(*)                                     AS AttendanceRows,
       SUM(CASE WHEN a.Status = 'Absent' THEN 1 ELSE 0 END) AS AbsentDays,
       CAST(100.0 * SUM(CASE WHEN a.Status = 'Absent' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS AbsentPct,
       CAST(100.0 * SUM(CASE WHEN a.Status = 'Leave'  THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS LeavePct
FROM dbo.Attendance AS a
WHERE a.AttendanceDate >= '2025-01-01' AND a.AttendanceDate < '2026-01-01'
GROUP BY MONTH(a.AttendanceDate)
ORDER BY MonthNo;
-- EXPECTED AbsentPct by month 1-12:
--   2.94 3.15 3.18 2.92 3.49 3.30 3.16 2.76 3.41 3.13 3.12 3.09     (highest: May 3.49%, then September 3.41%)
-- EXPECTED LeavePct by month 1-12:
--   5.77 5.58 5.62 5.70 7.55 5.73 5.70 5.77 5.34 6.41 5.60 8.69     (highest: December 8.69%, then May 7.55%)

/* ==========================================================
   SECTION F - Dates (date functions)
   ========================================================== */

-- F1. Date function behaviour with fixed literals (no table needed)
SELECT DATEDIFF(YEAR, '2025-12-31', '2026-01-01')  AS YearsBetween_Looks_Wrong,   -- 1 (crossed one year boundary, but only 1 DAY apart)
       DATEDIFF(DAY,  '2025-12-31', '2026-01-01')  AS DaysBetween,                -- 1
       EOMONTH('2025-02-15')                       AS EndOfFebruary,              -- 2025-02-28
       DATEADD(MONTH, 6, CAST('2025-08-31' AS DATE)) AS SixMonthsLater,             -- 2026-02-28 (clipped to month end)
       DATENAME(WEEKDAY, '2025-12-31')             AS DayName,                    -- Wednesday
       DATEPART(QUARTER, '2025-12-31')             AS QuarterNo,                  -- 4
       DATEFROMPARTS(2025, 4, 1)                   AS AprilFirst;                 -- 2025-04-01

-- F2. Hires in the last 12 months before the analysis date
GO
DECLARE @AsOfDate DATE = '2025-12-31';   -- GO above = fresh batch, so this name is never declared twice
SELECT COUNT(*) AS HiresLast12Months
FROM dbo.Employee
WHERE HireDate >  DATEADD(YEAR, -1, @AsOfDate)
  AND HireDate <= @AsOfDate;
-- EXPECTED: 62

-- F3. Exits per year
SELECT YEAR(ExitDate) AS ExitYear, COUNT(*) AS Exits
FROM dbo.EmployeeExit
GROUP BY YEAR(ExitDate)
ORDER BY ExitYear;
-- EXPECTED: 2022 20 | 2023 18 | 2024 27 | 2025 39      (total 104; exits are rising every year after 2023)

/* ==========================================================
   SECTION G - Attrition basics (Day 1 Q18-Q23)
   NOTE: "ExitPct" below = exits / everyone ever employed in that department.
   It is a quick screening number, NOT the formal attrition rate.
   The real KPI (exits in a period / average headcount) comes on Day 10.
   ========================================================== */

-- G1. Exits by department; HAVING keeps only departments with at least 10 exits.
--     COUNT(x.EmployeeID) counts only NON-NULL values = employees who HAVE an exit row.
SELECT d.DepartmentName,
       COUNT(*)             AS EverEmployed,
       COUNT(x.EmployeeID)  AS Exits,
       CAST(100.0 * COUNT(x.EmployeeID) / COUNT(*) AS DECIMAL(5,1)) AS ExitPct
FROM dbo.Employee AS e
JOIN dbo.Department AS d ON d.DepartmentID = e.DepartmentID
LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
GROUP BY d.DepartmentName
HAVING COUNT(x.EmployeeID) >= 10
ORDER BY ExitPct DESC;
-- EXPECTED: Customer Support 90/25 = 27.8 | Sales 100/21 = 21.0 | Engineering 150/28 = 18.7 | Operations 70/10 = 14.3
-- (Departments below 10 exits: IT 9, Marketing 6, Finance 4, HR 1 - remove the HAVING line to see them.)

-- G2. Exit reasons (Day 1 Q23)
SELECT r.ReasonName,
       r.ReasonCategory,
       COUNT(*) AS Exits,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,1)) AS Pct
FROM dbo.EmployeeExit AS x
JOIN dbo.ExitReason   AS r ON r.ExitReasonID = x.ExitReasonID
GROUP BY r.ReasonName, r.ReasonCategory
ORDER BY Exits DESC, r.ReasonName;
-- EXPECTED: Better Pay 24 (23.1) | Poor Management 17 (16.3) | Poor Performance 16 (15.4) | Work-Life Balance 14 (13.5) |
--           Career Growth 13 (12.5) | Relocation 10 (9.6) | Restructuring 5 (4.8) | Higher Studies 4 (3.8) | Misconduct 1 (1.0)

-- G3. Tenure at exit (Day 1 Q20)
SELECT CASE WHEN DATEDIFF(DAY, e.HireDate, x.ExitDate) < 365      THEN '1) Under 1 year'
            WHEN DATEDIFF(DAY, e.HireDate, x.ExitDate) < 3 * 365  THEN '2) 1 to under 3 years'
            ELSE '3) 3+ years' END AS TenureAtExit,
       COUNT(*) AS Exits
FROM dbo.EmployeeExit AS x
JOIN dbo.Employee     AS e ON e.EmployeeID = x.EmployeeID
GROUP BY CASE WHEN DATEDIFF(DAY, e.HireDate, x.ExitDate) < 365      THEN '1) Under 1 year'
              WHEN DATEDIFF(DAY, e.HireDate, x.ExitDate) < 3 * 365  THEN '2) 1 to under 3 years'
              ELSE '3) 3+ years' END
ORDER BY TenureAtExit;
-- EXPECTED: Under 1 year 35 | 1-3 years 29 | 3+ years 40      (total 104)

/* ==========================================================
   SECTION H - Compensation (Day 1 Q11)
   CURRENT salary = the salary row with the latest EffectiveDate per employee.
   (This MAX-join pattern is the "classic" way; Day 8 shows the CTE / ROW_NUMBER way.)
   ========================================================== */

-- H1. Salary summary by department, active employees only
SELECT d.DepartmentName,
       COUNT(*)                          AS Employees,
       CAST(ROUND(AVG(s.BaseSalary), 0) AS INT) AS AvgSalary,   -- ROUND first: CAST(decimal AS INT) truncates
       MIN(s.BaseSalary)                 AS MinSalary,
       MAX(s.BaseSalary)                 AS MaxSalary
FROM dbo.Employee AS e
JOIN dbo.Department AS d ON d.DepartmentID = e.DepartmentID
JOIN dbo.SalaryHistory AS s ON s.EmployeeID = e.EmployeeID
JOIN (SELECT EmployeeID, MAX(EffectiveDate) AS LastDate
      FROM dbo.SalaryHistory
      GROUP BY EmployeeID) AS l
  ON l.EmployeeID = s.EmployeeID AND l.LastDate = s.EffectiveDate
LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
WHERE x.EmployeeID IS NULL
GROUP BY d.DepartmentName
ORDER BY AvgSalary DESC;
-- EXPECTED AvgSalary: Engineering 1,095,342 | Finance 963,877 | HR 900,025 | IT 885,619 | Marketing 878,674 |
--                     Operations 864,645 | Sales 818,904 | Customer Support 659,425
-- EXPECTED MaxSalary for Operations = 5,989,300 (the CEO sits in Operations, so a single person lifts that department's range).
-- Business meaning: an AVERAGE can be distorted by one extreme value; on Day 9 you will add the median.

-- H2. Top 5 current salaries among active employees
SELECT TOP (5)
       e.EmployeeCode,
       CONCAT(e.FirstName, ' ', e.LastName) AS EmployeeName,
       j.JobTitle,
       s.BaseSalary
FROM dbo.Employee AS e
JOIN dbo.JobRole AS j ON j.JobRoleID = e.JobRoleID
JOIN dbo.SalaryHistory AS s ON s.EmployeeID = e.EmployeeID
JOIN (SELECT EmployeeID, MAX(EffectiveDate) AS LastDate
      FROM dbo.SalaryHistory
      GROUP BY EmployeeID) AS l
  ON l.EmployeeID = s.EmployeeID AND l.LastDate = s.EffectiveDate
LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
WHERE x.EmployeeID IS NULL
ORDER BY s.BaseSalary DESC, e.EmployeeCode;
-- EXPECTED: NP0001 Chief Executive Officer 5,989,300 | NP0002 Director of Engineering 3,621,200 |
--           NP0511 Head of IT 3,461,700 | NP0252 Head of Marketing 3,360,000 | NP0352 Head of Operations 3,360,000

/* ==========================================================
   SECTION I - String functions
   ========================================================== */

-- I1. Building and cleaning text
SELECT TOP (5)
       e.EmployeeCode,
       CONCAT(e.FirstName, ' ', e.LastName)                         AS FullName,
       CONCAT(UPPER(e.LastName), ', ', e.FirstName)                 AS LastFirst,
       LEN(e.Email)                                                 AS EmailLength,
       SUBSTRING(e.Email, CHARINDEX('@', e.Email) + 1, LEN(e.Email)) AS EmailDomain,
       CONCAT(LEFT(e.FirstName, 1), LEFT(e.LastName, 1))            AS Initials
FROM dbo.Employee AS e
ORDER BY e.EmployeeCode;
-- EXPECTED:
--   NP0001 Rajesh Mehta     | MEHTA, Rajesh     | 30 | northpeak.example | RM
--   NP0002 Anita Sharma     | SHARMA, Anita     | 30 | northpeak.example | AS
--   NP0003 Bhavna Chauhan   | CHAUHAN, Bhavna   | 32 | northpeak.example | BC
--   NP0004 Jyoti Agarwal    | AGARWAL, Jyoti    | 31 | northpeak.example | JA
--   NP0005 Simran Joshi     | JOSHI, Simran     | 30 | northpeak.example | SJ

-- I2. Pattern search with LIKE
SELECT COUNT(*) AS PeopleManagers
FROM dbo.Employee AS e
JOIN dbo.JobRole  AS j ON j.JobRoleID = e.JobRoleID
WHERE j.JobTitle LIKE '%Manager%';
-- EXPECTED: 45       (12 Engineering, 8 Sales, 8 Customer Support, 6 Operations, 3 each Marketing / Finance / IT, 2 HR)

-- I3. Find the placeholder e-mails created by Day 6 (pattern: firstname.lastname.np0000@...)
--     [0-9] means "one digit" inside a LIKE pattern.
SELECT COUNT(*) AS PlaceholderEmails
FROM dbo.Employee AS e
WHERE e.Email LIKE '%.np[0-9][0-9][0-9][0-9]@northpeak.example';
-- EXPECTED: 8        (matches the 8 imputed e-mails printed by 06_clean_and_load.sql)

/* ==========================================================
   SECTION J - NULL handling
   NULL = "unknown / not applicable". It is NOT zero and NOT an empty string.
   ========================================================== */

-- J1. COUNT(*) counts rows; COUNT(column) skips NULLs
SELECT COUNT(*)              AS TotalRows,
       COUNT(a.LeaveTypeID)  AS RowsWithLeaveType,
       COUNT(*) - COUNT(a.LeaveTypeID) AS RowsWithoutLeaveType
FROM dbo.Attendance AS a;
-- EXPECTED: 214,241 | 12,993 | 201,248     (NULL leave type is NORMAL on Present/WFH/Absent days)

-- J2. The classic trap: "= NULL" is never true. Use IS NULL.
SELECT (SELECT COUNT(*) FROM dbo.Attendance WHERE LeaveTypeID =  NULL) AS Wrong_EqualsNull,
       (SELECT COUNT(*) FROM dbo.Attendance WHERE LeaveTypeID IS NULL) AS Right_IsNull;
-- EXPECTED: 0 | 201,248

-- J3. COALESCE: first non-NULL value. Show "(top of hierarchy)" instead of NULL for the CEO.
SELECT TOP (3)
       e.EmployeeCode,
       COALESCE(CONCAT(m.FirstName, ' ', m.LastName), '(top of hierarchy)') AS ManagerName
FROM dbo.Employee AS e
LEFT JOIN dbo.Employee AS m ON m.EmployeeID = e.ManagerID     -- LEFT JOIN keeps the CEO
ORDER BY e.EmployeeCode;
-- EXPECTED: NP0001 (top of hierarchy) | NP0002 Rajesh Mehta | NP0003 Anita Sharma

-- J4. NULLIF turns a value into NULL; its main job is avoiding divide-by-zero.
SELECT 100 / NULLIF(0, 0)    AS SafeDivide,          -- NULL instead of an error
       ISNULL(NULL, 'N/A')   AS IsNullDemo,          -- N/A  (ISNULL takes 2 arguments; COALESCE takes many)
       COALESCE(NULL, NULL, 'third value') AS CoalesceDemo;

-- J5. Employees with NO salary record (rows quarantined on Day 6 leave gaps)
SELECT e.EmployeeCode, e.FirstName, e.LastName
FROM dbo.Employee AS e
LEFT JOIN dbo.SalaryHistory AS s ON s.EmployeeID = e.EmployeeID
WHERE s.EmployeeID IS NULL;
-- EXPECTED: 1 row  (NP0371 - an anti-join: LEFT JOIN + "right side IS NULL" = "has no match")
GO
