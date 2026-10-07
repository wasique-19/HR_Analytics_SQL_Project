/* ==========================================================
   File    : validation_checks.sql
   Purpose : Re-runnable data-quality checklist for the FINAL tables.
             Run after 06_clean_and_load.sql (and any time data changes).
   ========================================================== */
USE HR_Analytics;
GO

/* ---------- A. Reconciliation: every staging row is loaded OR rejected ---------- */
SELECT t.SourceTable, t.StagingRows, t.LoadedRows,
       ISNULL(r.Rejected, 0)                                  AS RejectedRows,
       t.StagingRows - t.LoadedRows - ISNULL(r.Rejected, 0)   AS Unaccounted,
       CASE WHEN t.StagingRows = t.LoadedRows + ISNULL(r.Rejected, 0) THEN 'OK' ELSE 'CHECK' END AS Result
FROM (
    SELECT 'Employee_Raw' AS SourceTable, (SELECT COUNT(*) FROM stg.Employee_Raw) AS StagingRows, (SELECT COUNT(*) FROM dbo.Employee) AS LoadedRows
    UNION ALL SELECT 'EmployeeExit_Raw',      (SELECT COUNT(*) FROM stg.EmployeeExit_Raw),      (SELECT COUNT(*) FROM dbo.EmployeeExit)
    UNION ALL SELECT 'SalaryHistory_Raw',     (SELECT COUNT(*) FROM stg.SalaryHistory_Raw),     (SELECT COUNT(*) FROM dbo.SalaryHistory)
    UNION ALL SELECT 'Attendance_Raw',        (SELECT COUNT(*) FROM stg.Attendance_Raw),        (SELECT COUNT(*) FROM dbo.Attendance)
    UNION ALL SELECT 'PerformanceReview_Raw', (SELECT COUNT(*) FROM stg.PerformanceReview_Raw), (SELECT COUNT(*) FROM dbo.PerformanceReview)
    UNION ALL SELECT 'Promotion_Raw',         (SELECT COUNT(*) FROM stg.Promotion_Raw),         (SELECT COUNT(*) FROM dbo.Promotion)
) AS t
LEFT JOIN (SELECT SourceTable, COUNT(*) AS Rejected FROM dq.RejectedRow GROUP BY SourceTable) AS r
       ON r.SourceTable = t.SourceTable;

/* ---------- B. Why rows were rejected ---------- */
SELECT SourceTable, RejectReason, COUNT(*) AS RowsRejected
FROM dq.RejectedRow
GROUP BY SourceTable, RejectReason
ORDER BY SourceTable, RowsRejected DESC;

/* ---------- C. Business-rule checks on the final tables ----------
   Violations should equal Expected. 'REVIEW' means: investigate. */
SELECT CheckName, Violations, Expected,
       CASE WHEN Violations = Expected THEN 'PASS' ELSE 'REVIEW' END AS Result
FROM (
    SELECT '01 Employees without a manager (the CEO only)' AS CheckName,
           (SELECT COUNT(*) FROM dbo.Employee WHERE ManagerID IS NULL) AS Violations, 1 AS Expected
    UNION ALL SELECT '02 Manager hired AFTER their report',
           (SELECT COUNT(*) FROM dbo.Employee e JOIN dbo.Employee m ON m.EmployeeID = e.ManagerID
            WHERE m.HireDate > e.HireDate), 0
    UNION ALL SELECT '03 Exit date before hire date',
           (SELECT COUNT(*) FROM dbo.EmployeeExit x JOIN dbo.Employee e ON e.EmployeeID = x.EmployeeID
            WHERE x.ExitDate < e.HireDate), 0
    UNION ALL SELECT '04 Attendance before hire or after exit',
           (SELECT COUNT(*) FROM dbo.Attendance a
            JOIN dbo.Employee e ON e.EmployeeID = a.EmployeeID
            LEFT JOIN dbo.EmployeeExit x ON x.EmployeeID = a.EmployeeID
            WHERE a.AttendanceDate < e.HireDate OR a.AttendanceDate > x.ExitDate), 0
    UNION ALL SELECT '05 Reviewer is not the employee''s manager',
           (SELECT COUNT(*) FROM dbo.PerformanceReview r JOIN dbo.Employee e ON e.EmployeeID = r.EmployeeID
            WHERE r.ReviewerID <> ISNULL(e.ManagerID, -1)), 0
    UNION ALL SELECT '06 Review dated after the employee exited',
           (SELECT COUNT(*) FROM dbo.PerformanceReview r JOIN dbo.EmployeeExit x ON x.EmployeeID = r.EmployeeID
            WHERE r.ReviewDate > x.ExitDate), 0
    UNION ALL SELECT '07 Latest promotion does not match current job role',
           (SELECT COUNT(*) FROM (SELECT EmployeeID, NewJobRoleID,
                                         ROW_NUMBER() OVER (PARTITION BY EmployeeID ORDER BY PromotionDate DESC) AS rn
                                  FROM dbo.Promotion) p
            JOIN dbo.Employee e ON e.EmployeeID = p.EmployeeID
            WHERE p.rn = 1 AND p.NewJobRoleID <> e.JobRoleID), 0
    UNION ALL SELECT '08 "Promotion" that does not raise the job level',
           (SELECT COUNT(*) FROM dbo.Promotion p
            JOIN dbo.JobRole oj ON oj.JobRoleID = p.OldJobRoleID
            JOIN dbo.JobRole nj ON nj.JobRoleID = p.NewJobRoleID
            WHERE p.MovementType = 'Promotion' AND nj.JobLevel <= oj.JobLevel), 0
    UNION ALL SELECT '09 Current salary below the role''s band minimum',
           (SELECT COUNT(*) FROM dbo.Employee e JOIN dbo.JobRole j ON j.JobRoleID = e.JobRoleID
            CROSS APPLY (SELECT TOP (1) s.BaseSalary FROM dbo.SalaryHistory s
                         WHERE s.EmployeeID = e.EmployeeID ORDER BY s.EffectiveDate DESC) cur
            WHERE cur.BaseSalary < j.MinSalary), 0
    UNION ALL SELECT '10 Current salary above 105% of the role''s band maximum',
           (SELECT COUNT(*) FROM dbo.Employee e JOIN dbo.JobRole j ON j.JobRoleID = e.JobRoleID
            CROSS APPLY (SELECT TOP (1) s.BaseSalary FROM dbo.SalaryHistory s
                         WHERE s.EmployeeID = e.EmployeeID ORDER BY s.EffectiveDate DESC) cur
            WHERE cur.BaseSalary > j.MaxSalary * 1.05), 0
    -- Known gaps caused by quarantined rows (HR follow-up items, see Day 6 notes):
    UNION ALL SELECT '11 Employees with NO salary history (gap from rejected rows)',
           (SELECT COUNT(*) FROM dbo.Employee e
            WHERE NOT EXISTS (SELECT 1 FROM dbo.SalaryHistory s WHERE s.EmployeeID = e.EmployeeID)), 1
    UNION ALL SELECT '12 Employees whose first salary record is not on the hire date',
           (SELECT COUNT(*) FROM dbo.Employee e
            JOIN (SELECT EmployeeID, MIN(EffectiveDate) AS FirstDate FROM dbo.SalaryHistory GROUP BY EmployeeID) f
              ON f.EmployeeID = e.EmployeeID
            WHERE f.FirstDate <> e.HireDate), 2
    UNION ALL SELECT '13 Active headcount = employees with no exit record (informational)',
           (SELECT COUNT(*) FROM dbo.Employee e
            WHERE NOT EXISTS (SELECT 1 FROM dbo.EmployeeExit x WHERE x.EmployeeID = e.EmployeeID)), 446
) AS c
ORDER BY CheckName;

/* ---------- D. HR follow-up list: rows we could not safely fix ---------- */
SELECT SourceTable, SourceRowID, RejectReason, RawValue
FROM dq.RejectedRow
WHERE SourceTable IN ('EmployeeExit_Raw', 'SalaryHistory_Raw', 'PerformanceReview_Raw')
ORDER BY SourceTable, RejectReason, SourceRowID;
GO
