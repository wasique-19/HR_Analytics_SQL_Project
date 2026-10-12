/* ==========================================================
   Project : Employee Performance & HR Analytics System
   File    : queries/03_subqueries.sql         (DAY 8, part 2 of 3)
   Purpose : Scalar, IN, NOT IN, EXISTS, NOT EXISTS and correlated subqueries.
   Needs   : Day 6 finished (cleaned data loaded).
   Run     : Highlight ONE query and press F5.

   EXPECTED values were calculated on the same cleaned dataset. They were NOT
   produced by a live SQL Server run; if yours differs, investigate it.
   ========================================================== */
USE HR_Analytics;
GO

/* ==========================================================
   1. SCALAR SUBQUERY - returns exactly ONE value, usable like a constant
   ========================================================== */

-- 1a. 2025 reviews with a rating ABOVE the company-wide 2025 average
SELECT COUNT(*) AS ReviewsAboveCompanyAverage
FROM dbo.PerformanceReview AS r
WHERE r.ReviewYear = 2025
  AND r.Rating > (SELECT AVG(CAST(Rating AS DECIMAL(5,2)))      -- the CAST matters: AVG of TINYINT truncates (Day 7)
                  FROM dbo.PerformanceReview
                  WHERE ReviewYear = 2025);
-- EXPECTED: 155    (the 2025 average is 3.17, so ratings 4 and 5 qualify: 114 + 41)
-- If the subquery returned 2 rows, SQL Server would raise an error: scalar means exactly one value.

/* ==========================================================
   2. IN subquery - and why IN beats JOIN when you only need "does it exist?"
   ========================================================== */

-- 2a. JOIN duplicates a person who appears twice; IN does not
SELECT
  (SELECT COUNT(*) FROM dbo.Employee AS e
   JOIN dbo.Promotion AS p ON p.EmployeeID = e.EmployeeID)                      AS JoinRows,
  (SELECT COUNT(*) FROM dbo.Employee
   WHERE EmployeeID IN (SELECT EmployeeID FROM dbo.Promotion))                  AS EmployeesPromoted;
-- EXPECTED: JoinRows 49 | EmployeesPromoted 48     (NP0234 has two promotions)
-- LESSON: a JOIN returns one row per MATCH; IN / EXISTS return one row per EMPLOYEE.
-- Counting "how many people" with a JOIN to a many-side table over-counts. This bug is very common.

/* ==========================================================
   3. NOT IN and the NULL trap  (a favourite interview question)
   ========================================================== */

-- 3a. "Employees who are NOT anyone's manager" - three ways, three answers
SELECT
  (SELECT COUNT(*) FROM dbo.Employee
   WHERE EmployeeID NOT IN (SELECT ManagerID FROM dbo.Employee))                          AS NotIn_WithNulls,
  (SELECT COUNT(*) FROM dbo.Employee
   WHERE EmployeeID NOT IN (SELECT ManagerID FROM dbo.Employee WHERE ManagerID IS NOT NULL)) AS NotIn_Fixed,
  (SELECT COUNT(*) FROM dbo.Employee AS e
   WHERE NOT EXISTS (SELECT 1 FROM dbo.Employee AS r WHERE r.ManagerID = e.EmployeeID))   AS NotExists;
-- EXPECTED: 0 | 496 | 496
-- WHY 0?  The CEO's ManagerID is NULL, so the list is (..., NULL). "x NOT IN (a, b, NULL)" means
--         x<>a AND x<>b AND x<>NULL, and "x<>NULL" is UNKNOWN, so the whole condition is never TRUE -> no rows.
-- RULE: with NOT IN, either filter NULLs out of the subquery, or (better) use NOT EXISTS, which is NULL-safe.

/* ==========================================================
   4. EXISTS / NOT EXISTS - "is there at least one matching row?"
   ========================================================== */

-- 4a. Leavers who had at least one review rated 4 or 5  (a first look at "regretted attrition", Day 10)
SELECT COUNT(*) AS LeaversEverRatedHigh
FROM dbo.Employee AS e
WHERE EXISTS (SELECT 1 FROM dbo.EmployeeExit AS x WHERE x.EmployeeID = e.EmployeeID)
  AND EXISTS (SELECT 1 FROM dbo.PerformanceReview AS r
              WHERE r.EmployeeID = e.EmployeeID AND r.Rating >= 4);
-- EXPECTED: 27     (out of 60 leavers who have at least one review row; the other 44 have none, mostly because they left
--                    before their first review. Some may also be rows quarantined on Day 6.)
-- WHY SELECT 1: EXISTS only checks whether a row exists, so the selected column does not matter.

-- 4b. Possible career stagnation: active level 1-2 staff, hired by 2020, never promoted
SELECT d.DepartmentName, COUNT(*) AS NeverPromoted
FROM dbo.Employee AS e
JOIN dbo.Department AS d ON d.DepartmentID = e.DepartmentID
WHERE NOT EXISTS (SELECT 1 FROM dbo.EmployeeExit AS x WHERE x.EmployeeID = e.EmployeeID)
  AND NOT EXISTS (SELECT 1 FROM dbo.Promotion    AS p WHERE p.EmployeeID = e.EmployeeID)
  AND e.HireDate <= '2020-12-31'
  AND (SELECT j.JobLevel FROM dbo.JobRole AS j WHERE j.JobRoleID = e.JobRoleID) <= 2     -- scalar subquery
GROUP BY d.DepartmentName
ORDER BY NeverPromoted DESC, d.DepartmentName;
-- EXPECTED: Engineering 17 | Customer Support 10 | IT 10 | Sales 10 | Marketing 6 | Operations 6 | Finance 5 | HR 2   (total 66)
-- BUSINESS MEANING: 66 people with 5+ years' tenure are still at junior levels. Day 13 will ask whether they leave more.

/* ==========================================================
   5. CORRELATED SUBQUERY - the inner query uses a column from the outer row,
      so it is (logically) re-evaluated for every outer row.
   ========================================================== */

-- 5a. 2025 reviews above THEIR OWN department's 2025 average
SELECT COUNT(*) AS AboveOwnDepartmentAverage
FROM dbo.PerformanceReview AS r
JOIN dbo.Employee AS e ON e.EmployeeID = r.EmployeeID
WHERE r.ReviewYear = 2025
  AND r.Rating > (SELECT AVG(CAST(r2.Rating AS DECIMAL(5,2)))
                  FROM dbo.PerformanceReview AS r2
                  JOIN dbo.Employee AS e2 ON e2.EmployeeID = r2.EmployeeID
                  WHERE r2.ReviewYear = 2025
                    AND e2.DepartmentID = e.DepartmentID);        -- <-- refers to the OUTER row's department
-- EXPECTED: 165     (Engineering 46, Sales 32, Customer Support 23, IT 18, Operations 16, Marketing 14, Finance 9, HR 7)

-- 5b. Correlated subqueries in the SELECT list: the "TOP 1 / latest row" pattern
SELECT e.EmployeeCode,
       (SELECT TOP (1) s.BaseSalary
        FROM dbo.SalaryHistory AS s
        WHERE s.EmployeeID = e.EmployeeID
        ORDER BY s.EffectiveDate DESC)                 AS CurrentSalary,
       (SELECT COUNT(*) FROM dbo.SalaryHistory AS s
        WHERE s.EmployeeID = e.EmployeeID)             AS SalaryRecords,
       (SELECT MAX(r.Rating) FROM dbo.PerformanceReview AS r
        WHERE r.EmployeeID = e.EmployeeID)             AS BestRating
FROM dbo.Employee AS e
WHERE e.EmployeeCode IN ('NP0001','NP0002','NP0003','NP0004','NP0005')
ORDER BY e.EmployeeCode;
-- EXPECTED:
--   NP0001  5,989,300  16 records  NULL   (the CEO is never reviewed: a MAX() over zero rows is NULL, not 0)
--   NP0002  3,621,200  15 records  5
--   NP0003  2,249,100  10 records  3
--   NP0004  2,266,300  11 records  3
--   NP0005  2,730,000  12 records  5
-- PERFORMANCE NOTE: a correlated subquery can run once per outer row. That is fine for 550 employees,
-- but on millions of rows prefer a join or ROW_NUMBER() (Day 9) and an index on (EmployeeID, EffectiveDate) (Day 11).

/* ==========================================================
   WHEN TO USE WHAT (write this in your notes)
   - Need columns from the other table?         -> JOIN
   - Only need "is there a match?"              -> EXISTS (or IN for short, NULL-free lists)
   - Need "is there NO match?"                  -> NOT EXISTS   (avoid NOT IN)
   - Need to compare with a single computed value -> scalar subquery
   - Compare each row with ITS OWN group's value -> correlated subquery, or a CTE/window function (cleaner)
   ========================================================== */
GO
