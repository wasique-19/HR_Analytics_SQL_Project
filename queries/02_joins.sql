/* ==========================================================
   Project : Employee Performance & HR Analytics System
   File    : queries/02_joins.sql              (DAY 8, part 1 of 3)
   Purpose : INNER, LEFT, RIGHT, SELF joins; joining one table twice;
             UNION / UNION ALL.
   Needs   : Day 6 finished (cleaned data loaded).
   Run     : Highlight ONE query and press F5. Every query ends with ;
   Analysis date: data ends 2025-12-31.

   EXPECTED values in comments were calculated on the same cleaned dataset
   (550 employees). They were NOT produced by a live SQL Server run, so if
   your number differs, investigate: that is a finding, not a failure.
   ========================================================== */
USE HR_Analytics;
GO

/* ==========================================================
   1. INNER JOIN  - keep ONLY rows that match on both sides
   ========================================================== */

-- 1a. Employee + Department + Job role + Location (4 tables, all keys are NOT NULL)
SELECT COUNT(*) AS JoinedRows
FROM dbo.Employee   AS e
JOIN dbo.Department AS d ON d.DepartmentID = e.DepartmentID
JOIN dbo.JobRole    AS j ON j.JobRoleID    = e.JobRoleID
JOIN dbo.Location   AS l ON l.LocationID   = e.LocationID;
-- EXPECTED: 550   (every employee matches, because every FK column is NOT NULL and enforced)
-- LESSON: after a join, ALWAYS compare the row count with the table you started from.

-- 1b. INNER JOIN silently shrinks the result when the other side is optional
SELECT COUNT(*) AS EmployeesWithExitRow
FROM dbo.Employee     AS e
JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID;
-- EXPECTED: 104   (only the leavers). To keep all 550 employees you need a LEFT JOIN.

/* ==========================================================
   2. LEFT JOIN  - keep ALL rows of the left table, NULLs where no match
   ========================================================== */

-- 2a. ANTI-JOIN: active employees who have NO performance review for 2025
--     (LEFT JOIN, then keep rows where the right side is NULL)
SELECT COUNT(*) AS ActiveWithout2025Review
FROM dbo.Employee AS e
LEFT JOIN dbo.EmployeeExit       AS x ON x.EmployeeID = e.EmployeeID
LEFT JOIN dbo.PerformanceReview  AS r ON r.EmployeeID = e.EmployeeID
                                     AND r.ReviewYear = 2025          -- the year filter belongs in ON (see 3a)
WHERE x.EmployeeID IS NULL        -- active
  AND r.EmployeeID IS NULL;       -- no matching review
-- EXPECTED: 34

-- 2b. Who are they? (hire year of those 34)
SELECT YEAR(e.HireDate) AS HireYear, COUNT(*) AS Employees
FROM dbo.Employee AS e
LEFT JOIN dbo.EmployeeExit      AS x ON x.EmployeeID = e.EmployeeID
LEFT JOIN dbo.PerformanceReview AS r ON r.EmployeeID = e.EmployeeID AND r.ReviewYear = 2025
WHERE x.EmployeeID IS NULL AND r.EmployeeID IS NULL
GROUP BY YEAR(e.HireDate)
ORDER BY HireYear;
-- EXPECTED: 2010 1 | 2017 1 | 2019 1 | 2021 1 | 2022 1 | 2024 1 | 2025 28
-- BUSINESS MEANING: 28 of the 34 are 2025 joiners (reviews are only created for people hired by 30 June),
-- so they are mostly NOT a problem. The other 6 are real gaps: pass that list to HR. (Some may be among the
-- review rows quarantined on Day 6.)

/* ==========================================================
   3. THE #1 LEFT JOIN TRAP: filter in ON vs filter in WHERE
   ========================================================== */

-- 3a. Same join, three different answers
SELECT
  (SELECT COUNT(*) FROM dbo.Employee AS e
   LEFT JOIN dbo.PerformanceReview AS r ON r.EmployeeID = e.EmployeeID)                        AS NoYearFilter,
  (SELECT COUNT(*) FROM dbo.Employee AS e
   LEFT JOIN dbo.PerformanceReview AS r ON r.EmployeeID = e.EmployeeID AND r.ReviewYear = 2025) AS FilterInOn,
  (SELECT COUNT(*) FROM dbo.Employee AS e
   LEFT JOIN dbo.PerformanceReview AS r ON r.EmployeeID = e.EmployeeID
   WHERE r.ReviewYear = 2025)                                                                  AS FilterInWhere;
-- EXPECTED: NoYearFilter 1480 | FilterInOn 550 | FilterInWhere 414
-- WHY:  - NoYearFilter: one row per (employee, review) + one row for each of the 74 people with no review at all
--       - FilterInOn:   the filter decides which reviews MATCH; all 550 employees survive (one 2025 row each, at most)
--       - FilterInWhere: WHERE runs AFTER the join and removes every NULL row -> the LEFT JOIN quietly becomes an INNER JOIN
-- RULE: a condition on the RIGHT table goes in ON (to keep the LEFT JOIN) - unless you are doing "IS NULL" anti-join tests.

/* ==========================================================
   4. RIGHT JOIN  - the mirror of LEFT JOIN (rarely used in practice)
   ========================================================== */

-- 4a. Job roles that nobody has ever been promoted INTO.
SELECT COUNT(*) AS RolesNeverPromotedInto
FROM dbo.Promotion AS p
RIGHT JOIN dbo.JobRole AS j ON j.JobRoleID = p.NewJobRoleID     -- keep ALL job roles (right table)
WHERE p.PromotionID IS NULL;
-- EXPECTED: 29   (out of 41 roles; only 12 roles appear as a promotion target)

-- 4b. The SAME query written as a LEFT JOIN (what most teams prefer: read tables left to right)
SELECT COUNT(*) AS RolesNeverPromotedInto
FROM dbo.JobRole AS j
LEFT JOIN dbo.Promotion AS p ON p.NewJobRoleID = j.JobRoleID
WHERE p.PromotionID IS NULL;
-- EXPECTED: 29   (identical)

-- 4c. Which levels are those 29 roles at?
SELECT j.JobLevel, COUNT(*) AS RolesNeverPromotedInto
FROM dbo.JobRole AS j
LEFT JOIN dbo.Promotion AS p ON p.NewJobRoleID = j.JobRoleID
WHERE p.PromotionID IS NULL
GROUP BY j.JobLevel
ORDER BY j.JobLevel;
-- EXPECTED: L1 8 | L2 3 | L3 1 | L4 8 | L5 8 | L6 1
-- BUSINESS MEANING / DATA LIMITATION: no promotion in this dataset ever leads INTO a manager or head role
-- (levels 4-6). Careers in the data stop at level 3. Put this in your Limitations section on Day 14.

/* ==========================================================
   5. SELF JOIN  - a table joined to itself (Employee -> Employee via ManagerID)
   ========================================================== */

-- 5a. Top 5 managers by number of ACTIVE direct reports   (Day 7 practical Q1)
SELECT TOP (5)
       m.EmployeeCode                         AS ManagerCode,
       CONCAT(m.FirstName, ' ', m.LastName)   AS ManagerName,
       jm.JobTitle                            AS ManagerTitle,
       COUNT(*)                               AS ActiveReports
FROM dbo.Employee AS e                                   -- e = the report
JOIN dbo.Employee AS m ON m.EmployeeID = e.ManagerID     -- m = that person's manager
JOIN dbo.JobRole  AS jm ON jm.JobRoleID = m.JobRoleID
LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
WHERE x.EmployeeID IS NULL
GROUP BY m.EmployeeID, m.EmployeeCode, m.FirstName, m.LastName, jm.JobTitle
ORDER BY ActiveReports DESC, m.EmployeeCode;
-- EXPECTED: NP0006 Divya Pandey (Engineering Manager) 18 | NP0255 Naveen Saxena (Marketing Manager) 16 |
--           NP0004 Jyoti Agarwal (Engineering Manager) 15 | NP0010 Tanvi Bhatt (Engineering Manager) 14 |
--           NP0353 Meera Bansal (Operations Manager) 13
-- BUSINESS MEANING: span of control varies a lot (13 to 18 for the busiest managers). Very wide spans often mean
-- less coaching time per person: a hypothesis to test against ratings on Day 13, not a conclusion.

-- 5b. Reporting lines that cross departments
SELECT COUNT(*) AS CrossDepartmentLines
FROM dbo.Employee AS e
JOIN dbo.Employee AS m ON m.EmployeeID = e.ManagerID
WHERE m.DepartmentID <> e.DepartmentID;
-- EXPECTED: 7   (the 7 department heads outside Operations report to the CEO, who sits in Operations)

/* ==========================================================
   6. Joining the SAME table twice (two different aliases)
   ========================================================== */

-- 6a. Promotions with the OLD role and the NEW role (JobRole joined twice)
SELECT TOP (5)
       e.EmployeeCode,
       oj.JobTitle AS FromRole,
       nj.JobTitle AS ToRole,
       p.PromotionDate
FROM dbo.Promotion AS p
JOIN dbo.Employee  AS e  ON e.EmployeeID  = p.EmployeeID
JOIN dbo.JobRole   AS oj ON oj.JobRoleID  = p.OldJobRoleID
JOIN dbo.JobRole   AS nj ON nj.JobRoleID  = p.NewJobRoleID
ORDER BY p.PromotionDate DESC, e.EmployeeCode;
-- EXPECTED (all dated 2025-04-01):
--   NP0047 Software Engineer Trainee -> Software Engineer
--   NP0049 Software Engineer Trainee -> Software Engineer
--   NP0057 Software Engineer         -> Senior Software Engineer
--   NP0065 Software Engineer Trainee -> Software Engineer
--   NP0207 Sales Executive           -> Senior Sales Executive

-- 6b. Most common promotion paths
SELECT TOP (6)
       CONCAT(oj.JobTitle, ' -> ', nj.JobTitle) AS PromotionPath,
       COUNT(*) AS Promotions
FROM dbo.Promotion AS p
JOIN dbo.JobRole   AS oj ON oj.JobRoleID = p.OldJobRoleID
JOIN dbo.JobRole   AS nj ON nj.JobRoleID = p.NewJobRoleID
GROUP BY oj.JobTitle, nj.JobTitle
ORDER BY Promotions DESC, PromotionPath;
-- EXPECTED: Software Engineer -> Senior Software Engineer 8 | Marketing Executive -> Senior Marketing Executive 7 |
--           Operations Executive -> Senior Operations Executive 5 | Sales Executive -> Senior Sales Executive 5 |
--           Sales Trainee -> Sales Executive 5 | Operations Trainee -> Operations Executive 4

-- 6c. Promotions per year (Day 1 Q15)
SELECT YEAR(PromotionDate) AS PromotionYear, COUNT(*) AS Promotions
FROM dbo.Promotion
GROUP BY YEAR(PromotionDate)
ORDER BY PromotionYear;
-- EXPECTED: 2023 11 | 2024 18 | 2025 20     (total 49, covering 48 different people: NP0234 was promoted twice)

/* ==========================================================
   7. UNION ALL / UNION  - stack result sets on top of each other
   Rules: same number of columns, compatible types; column names come from the FIRST query.
   ========================================================== */

-- 7a. Workforce movement: hires vs exits per year (UNION ALL keeps every row)
SELECT m.Yr,
       SUM(m.Hires) AS Hires,
       SUM(m.Exits) AS Exits,
       SUM(m.Hires) - SUM(m.Exits) AS NetChange
FROM (
      SELECT YEAR(HireDate) AS Yr, 1 AS Hires, 0 AS Exits
      FROM dbo.Employee
      WHERE HireDate >= '2022-01-01'
      UNION ALL
      SELECT YEAR(ExitDate), 0, 1
      FROM dbo.EmployeeExit
     ) AS m
GROUP BY m.Yr
ORDER BY m.Yr;
-- EXPECTED: 2022  81 hires, 20 exits, +61 | 2023  67, 18, +49 | 2024  77, 27, +50 | 2025  62, 39, +23
-- BUSINESS MEANING: the company keeps growing, but net growth fell from +61 to +23 as exits rose every year.

-- 7b. UNION ALL vs UNION: departments with a hire in 2025 ... and departments with an exit in 2025
--     UNION ALL (no de-duplication):
SELECT DISTINCT d.DepartmentName
FROM dbo.Employee AS e JOIN dbo.Department AS d ON d.DepartmentID = e.DepartmentID
WHERE e.HireDate >= '2025-01-01' AND e.HireDate < '2026-01-01'
UNION ALL
SELECT DISTINCT d.DepartmentName
FROM dbo.EmployeeExit AS x
JOIN dbo.Employee AS e ON e.EmployeeID = x.EmployeeID
JOIN dbo.Department AS d ON d.DepartmentID = e.DepartmentID
WHERE x.ExitDate >= '2025-01-01' AND x.ExitDate < '2026-01-01';
-- EXPECTED: 15 rows (8 departments hired + 7 had exits; HR had no exits in 2025)

--     UNION (removes duplicates, which requires an extra sort/hash step = slower on big data):
SELECT DISTINCT d.DepartmentName
FROM dbo.Employee AS e JOIN dbo.Department AS d ON d.DepartmentID = e.DepartmentID
WHERE e.HireDate >= '2025-01-01' AND e.HireDate < '2026-01-01'
UNION
SELECT DISTINCT d.DepartmentName
FROM dbo.EmployeeExit AS x
JOIN dbo.Employee AS e ON e.EmployeeID = x.EmployeeID
JOIN dbo.Department AS d ON d.DepartmentID = e.DepartmentID
WHERE x.ExitDate >= '2025-01-01' AND x.ExitDate < '2026-01-01';
-- EXPECTED: 8 rows (each department once)
-- RULE OF THUMB: use UNION ALL by default; use UNION only when you really need duplicates removed.
GO
