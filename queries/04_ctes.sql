/* ==========================================================
   Project : Employee Performance & HR Analytics System
   File    : queries/04_ctes.sql               (DAY 8, part 3 of 3)
   Purpose : Common Table Expressions (CTEs): single, chained, reused, recursive.
   Needs   : Day 6 finished (cleaned data loaded).
   Run     : Highlight ONE complete query (from WITH down to its final ;) and press F5.

   A CTE is a NAMED, TEMPORARY result set that exists only for the ONE statement
   that follows it. Think of it as giving a long subquery a readable name.

   EXPECTED values were calculated on the same cleaned dataset. They were NOT
   produced by a live SQL Server run; if yours differs, investigate it.
   ========================================================== */
USE HR_Analytics;
GO

/* ==========================================================
   1. A simple CTE: CURRENT salary with ROW_NUMBER()
      (replaces the "MAX(EffectiveDate) join" from Day 7; ROW_NUMBER is formally taught on Day 9)
   ========================================================== */
WITH CurrentSalary AS (
    SELECT EmployeeID,
           BaseSalary,
           ROW_NUMBER() OVER (PARTITION BY EmployeeID ORDER BY EffectiveDate DESC) AS rn   -- rn = 1 is the latest row
    FROM dbo.SalaryHistory
)
SELECT d.DepartmentName,
       COUNT(*) AS Employees,
       CAST(ROUND(AVG(cs.BaseSalary), 0) AS INT) AS AvgSalary
FROM dbo.Employee AS e
JOIN dbo.Department AS d  ON d.DepartmentID = e.DepartmentID
JOIN CurrentSalary  AS cs ON cs.EmployeeID  = e.EmployeeID AND cs.rn = 1
LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
WHERE x.EmployeeID IS NULL
GROUP BY d.DepartmentName
ORDER BY AvgSalary DESC;
-- EXPECTED (identical to Day 7 query H1 - two methods, one answer, which is how you validate a query):
--   Engineering 122 / 1,095,342 | Finance 31 / 963,877 | HR 24 / 900,025 | IT 31 / 885,619 |
--   Marketing 34 / 878,674 | Operations 60 / 864,645 | Sales 79 / 818,904 | Customer Support 65 / 659,425

/* ==========================================================
   2. Chained CTEs, with one CTE REUSED:
      "How many active employees earn more than THEIR department's average?"
      (This needed the current-salary logic twice in Day 8 part 2. A CTE writes it once.)
   ========================================================== */
WITH CurrentSalary AS (
    SELECT EmployeeID, BaseSalary,
           ROW_NUMBER() OVER (PARTITION BY EmployeeID ORDER BY EffectiveDate DESC) AS rn
    FROM dbo.SalaryHistory
),
ActiveSalary AS (                                   -- built ON TOP of the first CTE
    SELECT e.EmployeeID, e.DepartmentID, cs.BaseSalary
    FROM dbo.Employee AS e
    JOIN CurrentSalary AS cs ON cs.EmployeeID = e.EmployeeID AND cs.rn = 1
    LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
    WHERE x.EmployeeID IS NULL
),
DeptAverage AS (
    SELECT DepartmentID, AVG(BaseSalary) AS AvgSalary
    FROM ActiveSalary
    GROUP BY DepartmentID
)
SELECT d.DepartmentName,
       COUNT(*) AS ActiveEmployees,
       SUM(CASE WHEN a.BaseSalary > da.AvgSalary THEN 1 ELSE 0 END) AS AboveDeptAverage
FROM ActiveSalary AS a
JOIN DeptAverage  AS da ON da.DepartmentID = a.DepartmentID
JOIN dbo.Department AS d ON d.DepartmentID = a.DepartmentID
GROUP BY d.DepartmentName
ORDER BY d.DepartmentName;
-- EXPECTED (active / above own average): Customer Support 65/24 | Engineering 122/52 | Finance 31/12 | HR 24/9 |
--   IT 31/11 | Marketing 34/11 | Operations 60/19 | Sales 79/26     (total 446 / 164)
-- BUSINESS MEANING: only 37% of people earn more than their department average. A few very high earners
-- (department heads) pull every average upwards: this is a right-skewed distribution; use the MEDIAN (Day 9) too.

/* ==========================================================
   3. Several independent CTEs combined: the DEPARTMENT SCORECARD
      (a reusable summary that later feeds Day 10 KPIs and Day 12 views)
   ========================================================== */
WITH Headcount AS (
    SELECT e.DepartmentID, COUNT(*) AS ActiveHeadcount
    FROM dbo.Employee AS e
    LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
    WHERE x.EmployeeID IS NULL
    GROUP BY e.DepartmentID
),
Exits2025 AS (
    SELECT e.DepartmentID, COUNT(*) AS Exits
    FROM dbo.EmployeeExit AS x
    JOIN dbo.Employee AS e ON e.EmployeeID = x.EmployeeID
    WHERE x.ExitDate >= '2025-01-01' AND x.ExitDate < '2026-01-01'
    GROUP BY e.DepartmentID
),
Rating2025 AS (
    SELECT e.DepartmentID, AVG(CAST(r.Rating AS DECIMAL(5,2))) AS AvgRating
    FROM dbo.PerformanceReview AS r
    JOIN dbo.Employee AS e ON e.EmployeeID = r.EmployeeID
    WHERE r.ReviewYear = 2025
    GROUP BY e.DepartmentID
),
Absence2025 AS (
    SELECT e.DepartmentID,
           100.0 * SUM(CASE WHEN a.Status = 'Absent' THEN 1 ELSE 0 END) / COUNT(*) AS AbsentPct
    FROM dbo.Attendance AS a
    JOIN dbo.Employee AS e ON e.EmployeeID = a.EmployeeID
    WHERE a.AttendanceDate >= '2025-01-01' AND a.AttendanceDate < '2026-01-01'
    GROUP BY e.DepartmentID
)
SELECT d.DepartmentName,
       h.ActiveHeadcount,
       COALESCE(x.Exits, 0)                                                   AS Exits2025,
       CAST(100.0 * COALESCE(x.Exits, 0) / h.ActiveHeadcount AS DECIMAL(5,1)) AS ExitsPer100Active,
       CAST(r.AvgRating AS DECIMAL(4,2))                                      AS AvgRating2025,
       CAST(a.AbsentPct AS DECIMAL(5,2))                                      AS AbsentPct2025
FROM dbo.Department AS d
JOIN Headcount  AS h ON h.DepartmentID = d.DepartmentID
LEFT JOIN Exits2025 AS x ON x.DepartmentID = d.DepartmentID          -- LEFT: HR has no exits in 2025
JOIN Rating2025 AS r ON r.DepartmentID = d.DepartmentID
JOIN Absence2025 AS a ON a.DepartmentID = d.DepartmentID
ORDER BY ExitsPer100Active DESC, d.DepartmentName;
-- EXPECTED:
--   Department        Active Exits25 Per100  Rating Absent%
--   Customer Support    65     11    16.9    3.21   2.93
--   IT                  31      5    16.1    2.89   2.81
--   Sales               79      8    10.1    3.28   2.93
--   Operations          60      6    10.0    3.07   3.38
--   Marketing           34      3     8.8    3.15   3.71
--   Finance             31      2     6.5    3.11   3.39
--   Engineering        122      4     3.3    3.25   3.11
--   HR                  24      0     0.0    3.05   3.25
-- CAUTION: "ExitsPer100Active" is a SCREENING number (2025 exits divided by people still active at the end),
-- not the formal attrition rate. The correct formula (exits / AVERAGE headcount) is built on Day 10.
-- Look at the table, but do not write conclusions yet: with 0-11 exits per department, small counts move percentages a lot.

/* ==========================================================
   4. CTE for "time to first promotion" (Day 1 Q16)
   ========================================================== */
WITH FirstPromotion AS (
    SELECT EmployeeID, MIN(PromotionDate) AS FirstPromoDate
    FROM dbo.Promotion
    GROUP BY EmployeeID
)
SELECT COUNT(*) AS PromotedEmployees,
       CAST(AVG(DATEDIFF(DAY, e.HireDate, fp.FirstPromoDate) / 30.4375) AS DECIMAL(5,1)) AS AvgMonthsToFirstPromotion,
       CAST(MIN(DATEDIFF(DAY, e.HireDate, fp.FirstPromoDate) / 30.4375) AS DECIMAL(5,1)) AS MinMonths,
       CAST(MAX(DATEDIFF(DAY, e.HireDate, fp.FirstPromoDate) / 30.4375) AS DECIMAL(5,1)) AS MaxMonths
FROM FirstPromotion AS fp
JOIN dbo.Employee   AS e ON e.EmployeeID = fp.EmployeeID;
-- EXPECTED: 48 employees | average 38.5 months | minimum 12.0 | maximum 96.0
-- BUSINESS MEANING: typical wait is about 3 years 2 months; nobody is promoted before 12 months.
-- Caution: this counts only people who WERE promoted. People still waiting are not in it (survivorship bias).

/* ==========================================================
   5. CTEs used as two "snapshots" joined together: rating change 2024 -> 2025
      (LAG() does this more simply on Day 9)
   ========================================================== */
WITH R2024 AS (SELECT EmployeeID, Rating FROM dbo.PerformanceReview WHERE ReviewYear = 2024),
     R2025 AS (SELECT EmployeeID, Rating FROM dbo.PerformanceReview WHERE ReviewYear = 2025)
SELECT CASE WHEN b.Rating > a.Rating THEN 'Improved'
            WHEN b.Rating < a.Rating THEN 'Declined'
            ELSE 'Same' END AS RatingTrend,
       COUNT(*) AS Employees
FROM R2024 AS a
JOIN R2025 AS b ON b.EmployeeID = a.EmployeeID          -- INNER: only people reviewed in BOTH years
GROUP BY CASE WHEN b.Rating > a.Rating THEN 'Improved'
              WHEN b.Rating < a.Rating THEN 'Declined'
              ELSE 'Same' END
ORDER BY Employees DESC;
-- EXPECTED: Same 171 | Declined 92 | Improved 86      (349 people reviewed in both years)
-- BUSINESS MEANING: ratings are fairly stable year to year; about half the people keep the same rating.

/* ==========================================================
   6. RECURSIVE CTE: walk the reporting hierarchy
      Anchor member   = the starting row(s)        (the CEO: ManagerID IS NULL)
      Recursive member = joins back to the CTE itself, one level deeper each time
      Recursion stops when the recursive member returns no more rows.
   ========================================================== */

-- 6a. How many people sit at each level of the organisation?
WITH OrgChart AS (
    SELECT EmployeeID, ManagerID, 0 AS OrgLevel
    FROM dbo.Employee
    WHERE ManagerID IS NULL                                  -- anchor: the CEO
    UNION ALL
    SELECT e.EmployeeID, e.ManagerID, o.OrgLevel + 1         -- recursive: everyone reporting to the previous level
    FROM dbo.Employee AS e
    JOIN OrgChart     AS o ON e.ManagerID = o.EmployeeID
)
SELECT OrgLevel, COUNT(*) AS Employees
FROM OrgChart
GROUP BY OrgLevel
ORDER BY OrgLevel
OPTION (MAXRECURSION 20);                                    -- safety net against accidental infinite loops (default is 100)
-- EXPECTED: Level 0 = 1 (CEO) | Level 1 = 8 (department heads) | Level 2 = 45 (managers) | Level 3 = 496 (everyone else)
-- (all 550 people ever employed; the hierarchy is exactly 4 levels deep)

-- 6b. The chain of command above ONE employee (walks UPWARDS: each step joins to the manager)
WITH Chain AS (
    SELECT EmployeeID, ManagerID, 0 AS Step
    FROM dbo.Employee
    WHERE EmployeeCode = 'NP0100'
    UNION ALL
    SELECT e.EmployeeID, e.ManagerID, c.Step + 1
    FROM dbo.Employee AS e
    JOIN Chain        AS c ON e.EmployeeID = c.ManagerID
)
SELECT c.Step,
       e.EmployeeCode,
       CONCAT(e.FirstName, ' ', e.LastName) AS EmployeeName,
       j.JobTitle
FROM Chain AS c
JOIN dbo.Employee AS e ON e.EmployeeID = c.EmployeeID
JOIN dbo.JobRole  AS j ON j.JobRoleID  = e.JobRoleID
ORDER BY c.Step
OPTION (MAXRECURSION 20);
-- EXPECTED: 0 NP0100 Neha Yadav (Software Engineer) -> 1 NP0005 Simran Joshi (Engineering Manager) ->
--           2 NP0002 Anita Sharma (Director of Engineering) -> 3 NP0001 Rajesh Mehta (Chief Executive Officer)

/* ==========================================================
   CTE vs SUBQUERY vs TEMP TABLE (write this in your notes)
   - CTE         : readability; can be used several times in ONE statement; supports recursion; NOT stored.
   - Subquery    : fine for a one-off, short filter.
   - Temp table  : (#t) stored in tempdb; use when you reuse the result across SEVERAL statements or need an index on it.
   Important: a CTE is NOT automatically faster than a subquery. SQL Server may re-run its logic every time it is referenced.
   ========================================================== */
GO
