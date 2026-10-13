/* ==========================================================
   Project : Employee Performance & HR Analytics System
   File    : queries/05_window_functions.sql        (DAY 9)
   Purpose : Window functions: ROW_NUMBER, RANK, DENSE_RANK, NTILE, LAG, LEAD,
             FIRST_VALUE / LAST_VALUE, SUM() / AVG() OVER, running totals,
             moving averages, median (PERCENTILE_CONT), segmentation.
   Needs   : Day 6 finished (cleaned data loaded).
   Run     : Highlight ONE complete query (WITH ... down to its final ;) and press F5.

   A WINDOW FUNCTION calculates over a set of related rows WITHOUT collapsing them
   (GROUP BY collapses rows; OVER() keeps every row and adds a calculated column).
       function(...) OVER (PARTITION BY <group>  ORDER BY <order>  ROWS <frame>)
       PARTITION BY = restart the calculation for each group (like GROUP BY, but rows survive)
       ORDER BY     = the order inside each group (needed for ranking / running totals / LAG)
       ROWS ...     = which neighbouring rows are included (the "frame")
   Window functions are NOT allowed in WHERE. Calculate them in a CTE, then filter outside.

   EXPECTED values were calculated on the same cleaned dataset. They were NOT
   produced by a live SQL Server run; if yours differs, investigate it.
   ========================================================== */
USE HR_Analytics;
GO

/* ==========================================================
   1. ROW_NUMBER: first salary vs current salary (Day 8 practical Q1)
   ========================================================== */
WITH Ranked AS (
    SELECT EmployeeID,
           BaseSalary,
           ROW_NUMBER() OVER (PARTITION BY EmployeeID ORDER BY EffectiveDate ASC)  AS rn_first,   -- 1 = oldest record
           ROW_NUMBER() OVER (PARTITION BY EmployeeID ORDER BY EffectiveDate DESC) AS rn_last,    -- 1 = newest record
           COUNT(*)     OVER (PARTITION BY EmployeeID)                             AS SalaryRecords
    FROM dbo.SalaryHistory
),
Growth AS (
    SELECT f.EmployeeID,
           f.BaseSalary AS FirstSalary,
           l.BaseSalary AS CurrentSalary,
           f.SalaryRecords
    FROM Ranked AS f
    JOIN Ranked AS l ON l.EmployeeID = f.EmployeeID AND l.rn_last = 1
    WHERE f.rn_first = 1
)
SELECT TOP (5)
       e.EmployeeCode,
       g.FirstSalary,
       g.CurrentSalary,
       CAST(100.0 * (g.CurrentSalary - g.FirstSalary) / g.FirstSalary AS DECIMAL(6,1)) AS GrowthPct,
       g.SalaryRecords
FROM Growth AS g
JOIN dbo.Employee AS e ON e.EmployeeID = g.EmployeeID
LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
WHERE x.EmployeeID IS NULL AND g.SalaryRecords >= 2
ORDER BY GrowthPct DESC, e.EmployeeCode;
-- EXPECTED: NP0292 1,152,300 -> 3,031,900 = 163.1% (15 records) | NP0206 327,700 -> 842,400 = 157.1% (9) |
--           NP0421 1,174,300 -> 2,694,800 = 129.5% (15) | NP0001 2,655,600 -> 5,989,300 = 125.5% (16) |
--           NP0234 315,200 -> 700,000 = 122.1% (3)
-- READING IT: raw growth % rewards LONG TENURE (15 records = 15 years of increments). NP0234 is the interesting one:
-- only 3 records, promoted twice (2024 and 2025). Always show the denominator (records / years) next to a growth %.

/* ==========================================================
   2. ROW_NUMBER vs RANK vs DENSE_RANK - what happens with TIES
   ========================================================== */
WITH CurrentSalary AS (
    SELECT EmployeeID, BaseSalary,
           ROW_NUMBER() OVER (PARTITION BY EmployeeID ORDER BY EffectiveDate DESC) AS rn
    FROM dbo.SalaryHistory
)
SELECT TOP (8)
       e.EmployeeCode,
       cs.BaseSalary,
       ROW_NUMBER() OVER (ORDER BY cs.BaseSalary DESC, e.EmployeeCode) AS RowNum,    -- always unique: 1,2,3,4,5,6...
       RANK()       OVER (ORDER BY cs.BaseSalary DESC)                 AS Rnk,       -- ties share a rank, then SKIPS: 4,4,6
       DENSE_RANK() OVER (ORDER BY cs.BaseSalary DESC)                 AS DenseRnk   -- ties share a rank, NO skip: 4,4,5
FROM dbo.Employee AS e
JOIN CurrentSalary AS cs ON cs.EmployeeID = e.EmployeeID AND cs.rn = 1
LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
WHERE x.EmployeeID IS NULL
ORDER BY cs.BaseSalary DESC, e.EmployeeCode;
-- EXPECTED:
--   NP0001  5,989,300  1 1 1
--   NP0002  3,621,200  2 2 2
--   NP0511  3,461,700  3 3 3
--   NP0252  3,360,000  4 4 4      <- tie
--   NP0352  3,360,000  5 4 4      <- tie: RANK repeats 4, DENSE_RANK repeats 4, ROW_NUMBER breaks the tie arbitrarily (here by code)
--   NP0317  3,130,000  6 6 5      <- RANK skips 5; DENSE_RANK does not
--   NP0292  3,031,900  7 7 6
--   NP0152  2,901,300  8 8 7
-- WHEN TO USE: ROW_NUMBER = "pick exactly one row" (latest record, de-duplication).
--              RANK = sports-style ranking. DENSE_RANK = "top N distinct levels" (3rd highest salary).

/* ==========================================================
   3. PARTITION BY: the top non-management earner in EACH department
   ========================================================== */
WITH CurrentSalary AS (
    SELECT EmployeeID, BaseSalary,
           ROW_NUMBER() OVER (PARTITION BY EmployeeID ORDER BY EffectiveDate DESC) AS rn
    FROM dbo.SalaryHistory
),
Ranked AS (
    SELECT e.EmployeeCode, d.DepartmentName, j.JobTitle, cs.BaseSalary,
           ROW_NUMBER() OVER (PARTITION BY e.DepartmentID ORDER BY cs.BaseSalary DESC, e.EmployeeCode) AS DeptRank
    FROM dbo.Employee AS e
    JOIN dbo.Department AS d ON d.DepartmentID = e.DepartmentID
    JOIN dbo.JobRole    AS j ON j.JobRoleID    = e.JobRoleID
    JOIN CurrentSalary  AS cs ON cs.EmployeeID = e.EmployeeID AND cs.rn = 1
    LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
    WHERE x.EmployeeID IS NULL AND j.JobLevel <= 3
)
SELECT DepartmentName, EmployeeCode, JobTitle, BaseSalary
FROM Ranked
WHERE DeptRank = 1                      -- the window function is filtered OUTSIDE, in the next SELECT
ORDER BY DepartmentName;
-- EXPECTED: Customer Support NP0495 Senior Support Executive 892,500 | Engineering NP0030 Senior Software Engineer 1,680,000 |
--   Finance NP0327 Senior Finance Analyst 1,365,000 | HR NP0309 Senior HR Executive 1,155,000 |
--   IT NP0544 Senior IT Engineer 1,312,500 | Marketing NP0263 Senior Marketing Executive 1,260,000 |
--   Operations NP0373 Senior Operations Executive 1,155,000 | Sales NP0179 Senior Sales Executive 1,260,000
-- Change "= 1" to "<= 3" for a top-3 per department.

/* ==========================================================
   4. AVG() OVER: replaces yesterday's correlated subquery
      "Active employees earning more than THEIR department's average" (Day 8: 164)
   ========================================================== */
WITH CurrentSalary AS (
    SELECT EmployeeID, BaseSalary,
           ROW_NUMBER() OVER (PARTITION BY EmployeeID ORDER BY EffectiveDate DESC) AS rn
    FROM dbo.SalaryHistory
),
ActiveSalary AS (
    SELECT e.EmployeeID, e.DepartmentID, cs.BaseSalary,
           AVG(cs.BaseSalary) OVER (PARTITION BY e.DepartmentID) AS DeptAvgSalary   -- every row also carries its department average
    FROM dbo.Employee AS e
    JOIN CurrentSalary AS cs ON cs.EmployeeID = e.EmployeeID AND cs.rn = 1
    LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
    WHERE x.EmployeeID IS NULL
)
SELECT COUNT(*) AS AboveOwnDepartmentAverage
FROM ActiveSalary
WHERE BaseSalary > DeptAvgSalary;
-- EXPECTED: 164     (same answer as the Day 8 CTE: a different method that agrees = a validated result)

/* ==========================================================
   5. MEDIAN vs AVERAGE: PERCENTILE_CONT(0.5)
      (the "bonus" promised on Day 7: one very high salary drags an average up, but not a median)
   ========================================================== */
WITH CurrentSalary AS (
    SELECT EmployeeID, BaseSalary,
           ROW_NUMBER() OVER (PARTITION BY EmployeeID ORDER BY EffectiveDate DESC) AS rn
    FROM dbo.SalaryHistory
),
ActiveSalary AS (
    SELECT e.DepartmentID, cs.BaseSalary
    FROM dbo.Employee AS e
    JOIN CurrentSalary AS cs ON cs.EmployeeID = e.EmployeeID AND cs.rn = 1
    LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
    WHERE x.EmployeeID IS NULL
)
SELECT DISTINCT                                            -- DISTINCT collapses the repeated per-row values to one row per department
       d.DepartmentName,
       COUNT(*) OVER (PARTITION BY a.DepartmentID) AS Employees,
       CAST(ROUND(AVG(a.BaseSalary) OVER (PARTITION BY a.DepartmentID), 0) AS INT) AS AvgSalary,
       CAST(ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY a.BaseSalary)
                  OVER (PARTITION BY a.DepartmentID), 0) AS INT)                   AS MedianSalary
FROM ActiveSalary AS a
JOIN dbo.Department AS d ON d.DepartmentID = a.DepartmentID
ORDER BY MedianSalary DESC;
-- EXPECTED (employees / average / median):
--   Engineering 122 / 1,095,342 / 945,000 | Finance 31 / 963,877 / 794,200 | HR 24 / 900,025 / 753,600 |
--   Marketing 34 / 878,674 / 721,800 | IT 31 / 885,619 / 716,500 | Sales 79 / 818,904 / 659,300 |
--   Operations 60 / 864,645 / 606,350 | Customer Support 65 / 659,425 / 546,000
-- COMPANY-WIDE: 446 people, average 901,068, MEDIAN 706,100.
-- BUSINESS MEANING: in every department the average is 15-30% ABOVE the median, so the "typical" employee earns
-- noticeably LESS than the average suggests. Report the median (or both) to leadership when talking about "typical pay".
-- NOTE: PERCENTILE_CONT interpolates (the median of an even count is the mean of the middle two); PERCENTILE_DISC picks an actual value.

/* ==========================================================
   6. SUM(...) OVER (): share of the total
   ========================================================== */
WITH CurrentSalary AS (
    SELECT EmployeeID, BaseSalary,
           ROW_NUMBER() OVER (PARTITION BY EmployeeID ORDER BY EffectiveDate DESC) AS rn
    FROM dbo.SalaryHistory
)
SELECT d.DepartmentName,
       SUM(cs.BaseSalary) AS AnnualSalaryCost,
       CAST(100.0 * SUM(cs.BaseSalary) / SUM(SUM(cs.BaseSalary)) OVER () AS DECIMAL(5,1)) AS CostSharePct,   -- "total of all groups"
       COUNT(*) AS Headcount,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,1))                     AS HeadcountSharePct
FROM dbo.Employee AS e
JOIN dbo.Department AS d ON d.DepartmentID = e.DepartmentID
JOIN CurrentSalary  AS cs ON cs.EmployeeID = e.EmployeeID AND cs.rn = 1
LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
WHERE x.EmployeeID IS NULL
GROUP BY d.DepartmentName
ORDER BY AnnualSalaryCost DESC;
-- EXPECTED (annual cost in INR | cost % | headcount | headcount %):
--   Engineering 133,631,700 | 33.3 | 122 | 27.4        Sales 64,693,400 | 16.1 | 79 | 17.7
--   Operations 51,878,700 | 12.9 | 60 | 13.5            Customer Support 42,862,600 | 10.7 | 65 | 14.6
--   Finance 29,880,200 | 7.4 | 31 | 7.0                 Marketing 29,874,900 | 7.4 | 34 | 7.6
--   IT 27,454,200 | 6.8 | 31 | 7.0                      HR 21,600,600 | 5.4 | 24 | 5.4
-- TOTAL annual base salary cost of the 446 active employees = 401,876,300 (about INR 40.2 crore).
-- BUSINESS MEANING: Engineering is 27% of the people but 33% of the cost; Customer Support is 15% of people but 11% of cost.

/* ==========================================================
   7. LAG / LEAD: compare a row with the PREVIOUS / NEXT row of the same employee
   ========================================================== */

-- 7a. Rating change 2024 -> 2025   (Day 8 used two CTEs; LAG needs one)
WITH Ratings AS (
    SELECT EmployeeID, ReviewYear, Rating,
           LAG(Rating)     OVER (PARTITION BY EmployeeID ORDER BY ReviewYear) AS PrevRating,
           LAG(ReviewYear) OVER (PARTITION BY EmployeeID ORDER BY ReviewYear) AS PrevYear
    FROM dbo.PerformanceReview
)
SELECT CASE WHEN Rating > PrevRating THEN 'Improved'
            WHEN Rating < PrevRating THEN 'Declined'
            ELSE 'Same' END AS RatingTrend,
       COUNT(*) AS Employees
FROM Ratings
WHERE ReviewYear = 2025
  AND PrevYear   = 2024                      -- LAG gives the previous EXISTING row; check it really is last year
GROUP BY CASE WHEN Rating > PrevRating THEN 'Improved'
              WHEN Rating < PrevRating THEN 'Declined'
              ELSE 'Same' END
ORDER BY Employees DESC;
-- EXPECTED: Same 171 | Declined 92 | Improved 86      (identical to Day 8: two methods, one answer)

-- 7b. How big is each salary step, by reason?
WITH Steps AS (
    SELECT EmployeeID, ChangeReason, BaseSalary,
           LAG(BaseSalary) OVER (PARTITION BY EmployeeID ORDER BY EffectiveDate) AS PrevSalary
    FROM dbo.SalaryHistory
)
SELECT ChangeReason,
       COUNT(*) AS Changes,
       CAST(AVG(100.0 * (BaseSalary - PrevSalary) / PrevSalary) AS DECIMAL(5,1)) AS AvgIncreasePct,
       CAST(MIN(100.0 * (BaseSalary - PrevSalary) / PrevSalary) AS DECIMAL(5,1)) AS MinPct,
       CAST(MAX(100.0 * (BaseSalary - PrevSalary) / PrevSalary) AS DECIMAL(5,1)) AS MaxPct
FROM Steps
WHERE PrevSalary IS NOT NULL                 -- the first row of each employee has no previous row: LAG returns NULL
GROUP BY ChangeReason
ORDER BY ChangeReason;
-- EXPECTED: Annual Increment 1,905 changes | avg 5.9% | min 0.0% | max 19.1%
--           Promotion          49 changes | avg 27.2% | min 12.0% | max 75.0%
-- BUSINESS MEANING: a promotion brings about 4.6x the pay rise of a normal annual increment (27.2% vs 5.9%).
-- WATCH OUT: the 19.1% maximum is NP0213: 2023-04-01 -> 2025-04-01. A whole year is missing from the history, so LAG compares
-- with the previous record that EXISTS, and two years of increments are squeezed into one "step". Gaps inflate LAG results.

-- 7c. LAG and LEAD together: the promotion timeline of the one person promoted twice
SELECT e.EmployeeCode,
       p.PromotionDate,
       LAG(p.PromotionDate)  OVER (PARTITION BY p.EmployeeID ORDER BY p.PromotionDate) AS PreviousPromotion,
       LEAD(p.PromotionDate) OVER (PARTITION BY p.EmployeeID ORDER BY p.PromotionDate) AS NextPromotion
FROM dbo.Promotion AS p
JOIN dbo.Employee  AS e ON e.EmployeeID = p.EmployeeID
WHERE e.EmployeeCode = 'NP0234'
ORDER BY p.PromotionDate;
-- EXPECTED: NP0234  2024-04-01  PreviousPromotion NULL        NextPromotion 2025-04-01
--           NP0234  2025-04-01  PreviousPromotion 2024-04-01  NextPromotion NULL
-- (hired 2022-12-09; promoted exactly 12 months apart, i.e. the fastest possible path in this data)

/* ==========================================================
   8. FIRST_VALUE / LAST_VALUE and the FRAME TRAP
   ========================================================== */
SELECT TOP (3) *
FROM (
    SELECT s.EffectiveDate,
           s.BaseSalary,
           FIRST_VALUE(s.BaseSalary) OVER (ORDER BY s.EffectiveDate) AS FirstSalary,
           LAST_VALUE(s.BaseSalary)  OVER (ORDER BY s.EffectiveDate) AS LastValue_DefaultFrame,   -- WRONG: frame ends at the CURRENT row
           LAST_VALUE(s.BaseSalary)  OVER (ORDER BY s.EffectiveDate
                                           ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS LastValue_FullFrame
    FROM dbo.SalaryHistory AS s
    JOIN dbo.Employee AS e ON e.EmployeeID = s.EmployeeID
    WHERE e.EmployeeCode = 'NP0004'
) AS t
ORDER BY EffectiveDate DESC;
-- EXPECTED (latest 3 rows of NP0004):
--   2025-04-01  2,266,300  FirstSalary 1,360,200  Default 2,266,300  Full 2,266,300
--   2024-04-01  2,127,600  FirstSalary 1,360,200  Default 2,127,600  Full 2,266,300   <- default frame just echoes this row
--   2023-04-01  2,070,300  FirstSalary 1,360,200  Default 2,070,300  Full 2,266,300
-- WHY: with ORDER BY and no frame, SQL Server uses "from the first row up to the CURRENT row", so the "last" row it can see
-- is the current one. For LAST_VALUE always write ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING.

/* ==========================================================
   9. RUNNING TOTAL: headcount month by month (2022-2025)
      Needs a CALENDAR of every month; months with zero hires and zero exits would otherwise vanish.
   ========================================================== */
WITH Calendar AS (
    SELECT CAST('2022-01-01' AS DATE) AS MonthStart
    UNION ALL
    SELECT DATEADD(MONTH, 1, MonthStart) FROM Calendar WHERE MonthStart < '2025-12-01'
),
Movement AS (
    SELECT c.MonthStart,
           (SELECT COUNT(*) FROM dbo.Employee AS e
            WHERE e.HireDate >= c.MonthStart AND e.HireDate < DATEADD(MONTH, 1, c.MonthStart)) AS Hires,
           (SELECT COUNT(*) FROM dbo.EmployeeExit AS x
            WHERE x.ExitDate >= c.MonthStart AND x.ExitDate < DATEADD(MONTH, 1, c.MonthStart)) AS Exits
    FROM Calendar AS c
),
Opening AS (
    SELECT COUNT(*) AS OpeningHeadcount FROM dbo.Employee WHERE HireDate < '2022-01-01'
),
Running AS (
    SELECT m.MonthStart, m.Hires, m.Exits,
           o.OpeningHeadcount
             + SUM(m.Hires - m.Exits) OVER (ORDER BY m.MonthStart
                                            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS EndOfMonthHeadcount
    FROM Movement AS m
    CROSS JOIN Opening AS o
)
SELECT MonthStart, Hires, Exits, EndOfMonthHeadcount
FROM Running
WHERE MONTH(MonthStart) = 12 OR MonthStart IN ('2022-01-01', '2025-01-01')    -- filter AFTER the window is calculated
ORDER BY MonthStart
OPTION (MAXRECURSION 100);
-- EXPECTED: opening headcount on 2022-01-01 = 263
--   2022-01  hires 6,  exits 1  -> 268
--   2022-12  hires 11, exits 0  -> 324
--   2023-12  hires 8,  exits 3  -> 373
--   2024-12  hires 3,  exits 4  -> 423
--   2025-01  hires 2,  exits 3  -> 422
--   2025-12  hires 0,  exits 5  -> 446      <- equals the 446 active employees from Day 7: a reconciliation check on the whole pipeline
-- BUSINESS MEANING: headcount grew from 263 to 446 (+70%) in four years, but the growth in 2025 (+23) is far smaller than 2022 (+61).

/* ==========================================================
   10. MOVING AVERAGE: smooth a noisy monthly series
   ========================================================== */
WITH Calendar AS (
    SELECT CAST('2022-01-01' AS DATE) AS MonthStart
    UNION ALL
    SELECT DATEADD(MONTH, 1, MonthStart) FROM Calendar WHERE MonthStart < '2025-12-01'
),
MonthlyExits AS (
    SELECT c.MonthStart,
           (SELECT COUNT(*) FROM dbo.EmployeeExit AS x
            WHERE x.ExitDate >= c.MonthStart AND x.ExitDate < DATEADD(MONTH, 1, c.MonthStart)) AS Exits
    FROM Calendar AS c
),
Smoothed AS (
    SELECT MonthStart, Exits,
           CAST(AVG(1.0 * Exits) OVER (ORDER BY MonthStart
                                       ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS DECIMAL(4,2)) AS MovingAvg3Months
    FROM MonthlyExits
)
SELECT MonthStart, Exits, MovingAvg3Months
FROM Smoothed
WHERE MonthStart >= '2025-01-01'
ORDER BY MonthStart
OPTION (MAXRECURSION 100);
-- EXPECTED (Jan-Dec 2025):
--   exits per month: 3 1 4 4 3 4 2 4 3 2 4 5
--   3-month avg:     3.00 2.00 2.67 3.00 3.67 3.67 3.00 3.33 3.00 3.00 3.00 3.67
-- BUSINESS MEANING: the monthly numbers jump between 1 and 5, but the moving average sits steadily around 3 exits a month;
-- December's 5 pushes the latest value to 3.67, the joint-highest of the year.
-- EDGE EFFECT: the FIRST two months of any series average fewer than 3 months (2022: 1.00, 0.50, 0.67 ...).
-- Do not read the first rows of a moving average as a real trend.

/* ==========================================================
   11. NTILE: segmentation - performance band x pay quartile
       Pay quartile is calculated WITHIN each job level (so a Level-1 trainee is not compared with a manager).
       Quartile 1 = lowest-paid 25% of that level, Quartile 4 = highest-paid 25%.
   ========================================================== */
WITH CurrentSalary AS (
    SELECT EmployeeID, BaseSalary,
           ROW_NUMBER() OVER (PARTITION BY EmployeeID ORDER BY EffectiveDate DESC) AS rn
    FROM dbo.SalaryHistory
),
Base AS (
    SELECT e.EmployeeID, j.JobLevel, cs.BaseSalary, r.Rating
    FROM dbo.Employee AS e
    JOIN dbo.JobRole  AS j  ON j.JobRoleID   = e.JobRoleID
    JOIN CurrentSalary AS cs ON cs.EmployeeID = e.EmployeeID AND cs.rn = 1
    JOIN dbo.PerformanceReview AS r ON r.EmployeeID = e.EmployeeID AND r.ReviewYear = 2025
    LEFT JOIN dbo.EmployeeExit AS x ON x.EmployeeID = e.EmployeeID
    WHERE x.EmployeeID IS NULL
),
Quartiles AS (
    SELECT EmployeeID, Rating,
           NTILE(4) OVER (PARTITION BY JobLevel ORDER BY BaseSalary, EmployeeID) AS PayQuartile
    FROM Base
)
SELECT CASE WHEN Rating >= 4 THEN '1) High (4-5)'
            WHEN Rating = 3  THEN '2) Mid (3)'
            ELSE '3) Low (1-2)' END AS PerformanceBand,
       SUM(CASE WHEN PayQuartile = 1 THEN 1 ELSE 0 END) AS Q1_LowestPaid,
       SUM(CASE WHEN PayQuartile = 2 THEN 1 ELSE 0 END) AS Q2,
       SUM(CASE WHEN PayQuartile = 3 THEN 1 ELSE 0 END) AS Q3,
       SUM(CASE WHEN PayQuartile = 4 THEN 1 ELSE 0 END) AS Q4_HighestPaid,
       COUNT(*) AS Total
FROM Quartiles
GROUP BY CASE WHEN Rating >= 4 THEN '1) High (4-5)'
              WHEN Rating = 3  THEN '2) Mid (3)'
              ELSE '3) Low (1-2)' END
ORDER BY PerformanceBand;
-- EXPECTED (412 active employees with a 2025 review):
--   High (4-5)   39  34  37  45   | 155
--   Mid (3)      36  38  41  39   | 154
--   Low (1-2)    29  31  25  18   | 103
-- BUSINESS MEANING: 39 high performers (25% of the 155) sit in the LOWEST pay quartile of their level. They are
-- a candidate "retention-risk" list for HR. Pay follows performance only weakly: high performers are spread almost evenly
-- across the quartiles (39/34/37/45), while low performers lean towards the bottom (29 vs 18 at the top).
-- CAUTION: NTILE splits equal salaries across quartiles arbitrarily; levels 4-6 have very few people, so their quartiles are tiny.
-- Treat this as a screening segmentation, then test the pay-vs-attrition link properly on Day 13.
GO
