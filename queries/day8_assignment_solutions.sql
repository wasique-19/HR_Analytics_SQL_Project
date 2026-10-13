/* ==========================================================
   File    : queries/day8_assignment_solutions.sql
   Purpose : Model answers for the DAY 8 practical assignment.
             Try each question yourself FIRST, then compare.
   Note    : Expected values were calculated on the same cleaned dataset
             (not by a live SQL Server run).
   ========================================================== */
USE HR_Analytics;
GO

-- Q1. Top 5 salary growth, first record -> current salary
--     -> solved in queries/05_window_functions.sql, query 1 (ROW_NUMBER ascending + descending).

-- Q2. Active employees with at least ONE month in 2025 containing 5 or more absent days
WITH AbsentByMonth AS (
    SELECT EmployeeID, MONTH(AttendanceDate) AS MonthNo, COUNT(*) AS AbsentDays
    FROM dbo.Attendance
    WHERE Status = 'Absent'
      AND AttendanceDate >= '2025-01-01' AND AttendanceDate < '2026-01-01'
    GROUP BY EmployeeID, MONTH(AttendanceDate)
    HAVING COUNT(*) >= 5
)
SELECT COUNT(*) AS Employees
FROM dbo.Employee AS e
WHERE NOT EXISTS (SELECT 1 FROM dbo.EmployeeExit AS x WHERE x.EmployeeID = e.EmployeeID)
  AND EXISTS     (SELECT 1 FROM AbsentByMonth AS a WHERE a.EmployeeID = e.EmployeeID);
-- EXPECTED: 6
-- CONTEXT: only 6 employee-months in all of 2025 reached 5 absent days (the worst was 7); 52 reached 4 or more; 201 reached 3 or more.
-- Absence is rare and spread thinly: no small group of "chronic absentees" is driving the 3% rate.

-- Q3. Active employees whose manager earns LESS THAN OR EQUAL TO them
WITH CurrentSalary AS (
    SELECT EmployeeID, BaseSalary,
           ROW_NUMBER() OVER (PARTITION BY EmployeeID ORDER BY EffectiveDate DESC) AS rn
    FROM dbo.SalaryHistory
)
SELECT COUNT(*) AS ReportsEarningAsMuchAsManager
FROM dbo.Employee AS e
JOIN dbo.Employee AS m ON m.EmployeeID = e.ManagerID
JOIN CurrentSalary AS ce ON ce.EmployeeID = e.EmployeeID AND ce.rn = 1
JOIN CurrentSalary AS cm ON cm.EmployeeID = m.EmployeeID AND cm.rn = 1
LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
WHERE x.EmployeeID IS NULL
  AND cm.BaseSalary <= ce.BaseSalary;
-- EXPECTED: 0      (out of 445 active people who have a manager with a salary record)
-- READING IT: a healthy sanity check. "Nobody out-earns their manager" is what a clean hierarchy and a sound salary-band
-- design should give. If this returned a lot of rows, it would point to pay compression or a data error.

-- Q4. Scorecard column: % of ACTIVE employees rated 4-5 in 2025
WITH Headcount AS (
    SELECT e.DepartmentID, COUNT(*) AS Active
    FROM dbo.Employee AS e
    LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
    WHERE x.EmployeeID IS NULL
    GROUP BY e.DepartmentID
),
HighPerf AS (
    SELECT e.DepartmentID, COUNT(*) AS HighPerformers
    FROM dbo.Employee AS e
    JOIN dbo.PerformanceReview AS r ON r.EmployeeID = e.EmployeeID AND r.ReviewYear = 2025 AND r.Rating >= 4
    LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
    WHERE x.EmployeeID IS NULL
    GROUP BY e.DepartmentID
)
SELECT d.DepartmentName, h.Active, p.HighPerformers,
       CAST(100.0 * p.HighPerformers / h.Active AS DECIMAL(5,1)) AS HighPerformerPctOfActive
FROM dbo.Department AS d
JOIN Headcount AS h ON h.DepartmentID = d.DepartmentID
JOIN HighPerf  AS p ON p.DepartmentID = d.DepartmentID
ORDER BY HighPerformerPctOfActive DESC, d.DepartmentName;
-- EXPECTED: Marketing 14/34 = 41.2 | Sales 32/79 = 40.5 | Engineering 46/122 = 37.7 | Customer Support 23/65 = 35.4 |
--           HR 7/24 = 29.2 | Finance 9/31 = 29.0 | Operations 16/60 = 26.7 | IT 8/31 = 25.8
-- WHY THIS DIFFERS FROM DAY 7 (Sales 42.7%, Marketing 42.4%): Day 7 divided by REVIEWED people (reviews that exist in 2025);
-- this divides by ALL active people, including those with no 2025 review (e.g. 2025 joiners). Both are correct,
-- they answer different questions. State the denominator every time you quote a percentage.
-- (Numerators can also differ by one: Day 7 counted every 2025 review, here only people still active.)

-- Q5 (bonus). Full reporting path as text, with a recursive CTE
WITH OrgPath AS (
    SELECT EmployeeID, ManagerID,
           CAST(CONCAT(FirstName, ' ', LastName) AS NVARCHAR(500)) AS ReportingPath,   -- CAST: the anchor decides the column length
           0 AS OrgLevel
    FROM dbo.Employee
    WHERE ManagerID IS NULL
    UNION ALL
    SELECT e.EmployeeID, e.ManagerID,
           CAST(CONCAT(o.ReportingPath, ' > ', e.FirstName, ' ', e.LastName) AS NVARCHAR(500)),
           o.OrgLevel + 1
    FROM dbo.Employee AS e
    JOIN OrgPath AS o ON e.ManagerID = o.EmployeeID
)
SELECT e.EmployeeCode, p.ReportingPath, p.OrgLevel
FROM OrgPath AS p
JOIN dbo.Employee AS e ON e.EmployeeID = p.EmployeeID
WHERE e.EmployeeCode IN ('NP0001', 'NP0002', 'NP0100')
ORDER BY p.OrgLevel
OPTION (MAXRECURSION 20);
-- EXPECTED: NP0001 'Rajesh Mehta' (level 0) | NP0002 'Rajesh Mehta > Anita Sharma' (1) |
--           NP0100 'Rajesh Mehta > Anita Sharma > Simran Joshi > Neha Yadav' (3)
-- THE TRAP: if the anchor column is not CAST to a wide type, SQL Server fixes the length from the SHORT anchor text
-- and the recursive part fails with "Types don't match between the anchor and the recursive part" (Msg 240).
GO
