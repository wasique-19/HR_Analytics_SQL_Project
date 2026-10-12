/* ==========================================================
   File    : queries/day7_assignment_solutions.sql
   Purpose : Model answers for the DAY 7 practical assignment.
             Try each question yourself FIRST, then compare.
   Note    : Expected values were calculated on the same cleaned dataset
             (not by a live SQL Server run).
   ========================================================== */
USE HR_Analytics;
GO

-- Q1. Top 5 managers by active direct reports
--     -> solved in queries/02_joins.sql, query 5a (a SELF JOIN).

-- Q2. High performers (rating 4 or 5) per department, review year 2025
SELECT d.DepartmentName,
       COUNT(*) AS Reviews,
       SUM(CASE WHEN r.Rating >= 4 THEN 1 ELSE 0 END) AS HighPerformers,
       CAST(100.0 * SUM(CASE WHEN r.Rating >= 4 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,1)) AS HighPerformerPct
FROM dbo.PerformanceReview AS r
JOIN dbo.Employee   AS e ON e.EmployeeID   = r.EmployeeID
JOIN dbo.Department AS d ON d.DepartmentID = e.DepartmentID
WHERE r.ReviewYear = 2025
GROUP BY d.DepartmentName
ORDER BY HighPerformerPct DESC, d.DepartmentName;
-- EXPECTED: Sales 32/75 42.7 | Marketing 14/33 42.4 | Customer Support 23/56 41.1 | Engineering 46/116 39.7 |
--           Finance 9/27 33.3 | HR 7/22 31.8 | IT 8/28 28.6 | Operations 16/57 28.1
-- The "SUM(CASE ...)" pattern = "count the rows that meet a condition": a core analyst technique.

-- Q3. Average tenure at exit, by exit reason
SELECT r.ReasonName,
       COUNT(*) AS Exits,
       CAST(AVG(DATEDIFF(DAY, e.HireDate, x.ExitDate) / 365.25) AS DECIMAL(4,1)) AS AvgTenureYears
FROM dbo.EmployeeExit AS x
JOIN dbo.Employee   AS e ON e.EmployeeID   = x.EmployeeID
JOIN dbo.ExitReason AS r ON r.ExitReasonID = x.ExitReasonID
GROUP BY r.ReasonName
ORDER BY AvgTenureYears, r.ReasonName;
-- EXPECTED: Misconduct 1 / 0.5 | Restructuring 5 / 1.4 | Higher Studies 4 / 1.9 | Poor Management 17 / 2.1 |
--           Better Pay 24 / 2.3 | Poor Performance 16 / 2.6 | Career Growth 13 / 2.7 | Work-Life Balance 14 / 3.3 |
--           Relocation 10 / 4.3
-- READING IT: "Better Pay" leavers go after about 2.3 years, earlier than "Relocation" (4.3). Misconduct has ONE row,
-- so its 0.5 is an anecdote, not an average. Always look at the Exits column next to any average.

-- Q5 (bonus). Absenteeism by gender, 2025
SELECT e.Gender,
       COUNT(*) AS AttendanceRows,
       CAST(100.0 * SUM(CASE WHEN a.Status = 'Absent' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS AbsenteeismPct
FROM dbo.Attendance AS a
JOIN dbo.Employee   AS e ON e.EmployeeID = a.EmployeeID
WHERE a.AttendanceDate >= '2025-01-01' AND a.AttendanceDate < '2026-01-01'
GROUP BY e.Gender
ORDER BY e.Gender;
-- EXPECTED: F 43,040 rows / 2.95% | M 66,782 / 3.28% | O 1,884 / 2.65%
-- THE QUESTION BEHIND THE QUESTION: M shows 0.33 percentage points more absence than F. Before saying "men are absent more":
--   (1) the departments have different gender mixes AND different absence levels (Marketing 3.71% vs IT 2.81%),
--   (2) tenure, role level and employment type may differ,
--   (3) "O" has only 1,884 rows (7 active people), too few to read anything into.
-- A fair comparison would hold department constant (compare M vs F INSIDE each department). That is a good Day 13 exercise.
GO
