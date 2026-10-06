/* ==========================================================
   File    : 04b_test_data.sql
   Purpose : TEMPORARY test rows to prove the design works.
   Cleanup : Re-run 01 -> 04 to wipe these. Never run on real data.
   Fix     : Employees inserted level by level (one INSERT per
             hierarchy level) so every manager already exists.
   ========================================================== */
USE HR_Analytics;
GO

-- 1) Level 1: CEO (no manager)
INSERT INTO dbo.Employee
 (EmployeeCode, FirstName, LastName, Gender, DateOfBirth, Email, HireDate,
  EmploymentType, DepartmentID, JobRoleID, LocationID, ManagerID)
SELECT v.Code, v.FirstName, v.LastName, v.Gender, v.DOB, v.Email, v.HireDate,
       'Full-Time', d.DepartmentID, j.JobRoleID, l.LocationID, NULL
FROM (VALUES
 ('NP0001','Rajesh','Mehta','M','1975-04-12','rajesh.mehta@northpeak.example',
  '2010-06-01','Operations','Chief Executive Officer','Mumbai')
) AS v (Code, FirstName, LastName, Gender, DOB, Email, HireDate, DeptName, JobTitle, City)
JOIN dbo.Department AS d ON d.DepartmentName = v.DeptName
JOIN dbo.JobRole    AS j ON j.DepartmentID = d.DepartmentID AND j.JobTitle = v.JobTitle
JOIN dbo.Location   AS l ON l.City = v.City;

-- 2a) Level 2: reports to CEO (NP0001)
INSERT INTO dbo.Employee
 (EmployeeCode, FirstName, LastName, Gender, DateOfBirth, Email, HireDate,
  EmploymentType, DepartmentID, JobRoleID, LocationID, ManagerID)
SELECT v.Code, v.FirstName, v.LastName, v.Gender, v.DOB, v.Email, v.HireDate,
       'Full-Time', d.DepartmentID, j.JobRoleID, l.LocationID, m.EmployeeID
FROM (VALUES
 ('NP0002','Anita','Sharma','F','1982-09-23','anita.sharma@northpeak.example',
  '2012-03-15','Engineering','Director of Engineering','Bengaluru','NP0001')
) AS v (Code, FirstName, LastName, Gender, DOB, Email, HireDate, DeptName, JobTitle, City, MgrCode)
JOIN dbo.Department AS d ON d.DepartmentName = v.DeptName
JOIN dbo.JobRole    AS j ON j.DepartmentID = d.DepartmentID AND j.JobTitle = v.JobTitle
JOIN dbo.Location   AS l ON l.City = v.City
JOIN dbo.Employee   AS m ON m.EmployeeCode = v.MgrCode;

-- 2b) Level 3: reports to Anita (NP0002)
INSERT INTO dbo.Employee
 (EmployeeCode, FirstName, LastName, Gender, DateOfBirth, Email, HireDate,
  EmploymentType, DepartmentID, JobRoleID, LocationID, ManagerID)
SELECT v.Code, v.FirstName, v.LastName, v.Gender, v.DOB, v.Email, v.HireDate,
       'Full-Time', d.DepartmentID, j.JobRoleID, l.LocationID, m.EmployeeID
FROM (VALUES
 ('NP0003','Vikram','Singh','M','1990-01-30','vikram.singh@northpeak.example',
  '2019-07-01','Engineering','Engineering Manager','Bengaluru','NP0002')
) AS v (Code, FirstName, LastName, Gender, DOB, Email, HireDate, DeptName, JobTitle, City, MgrCode)
JOIN dbo.Department AS d ON d.DepartmentName = v.DeptName
JOIN dbo.JobRole    AS j ON j.DepartmentID = d.DepartmentID AND j.JobTitle = v.JobTitle
JOIN dbo.Location   AS l ON l.City = v.City
JOIN dbo.Employee   AS m ON m.EmployeeCode = v.MgrCode;

-- 2c) Level 4: reports to Vikram (NP0003)
INSERT INTO dbo.Employee
 (EmployeeCode, FirstName, LastName, Gender, DateOfBirth, Email, HireDate,
  EmploymentType, DepartmentID, JobRoleID, LocationID, ManagerID)
SELECT v.Code, v.FirstName, v.LastName, v.Gender, v.DOB, v.Email, v.HireDate,
       'Full-Time', d.DepartmentID, j.JobRoleID, l.LocationID, m.EmployeeID
FROM (VALUES
 ('NP0004','Priya','Nair','F','1995-11-05','priya.nair@northpeak.example',
  '2022-08-16','Engineering','Software Engineer','Bengaluru','NP0003'),
 ('NP0005','Arjun','Verma','M','1998-02-17','arjun.verma@northpeak.example',
  '2023-01-09','Engineering','Software Engineer','Pune','NP0003')
) AS v (Code, FirstName, LastName, Gender, DOB, Email, HireDate, DeptName, JobTitle, City, MgrCode)
JOIN dbo.Department AS d ON d.DepartmentName = v.DeptName
JOIN dbo.JobRole    AS j ON j.DepartmentID = d.DepartmentID AND j.JobTitle = v.JobTitle
JOIN dbo.Location   AS l ON l.City = v.City
JOIN dbo.Employee   AS m ON m.EmployeeCode = v.MgrCode;

-- SAFETY CHECK: must return 5. If not, STOP and investigate.
SELECT COUNT(*) AS EmployeeCount FROM dbo.Employee;
GO

-- 3) Salary history
INSERT INTO dbo.SalaryHistory (EmployeeID, EffectiveDate, BaseSalary, ChangeReason)
SELECT e.EmployeeID, v.EffDate, v.Salary, v.Reason
FROM (VALUES
 ('NP0004','2022-08-16', 800000,'Hire'),
 ('NP0004','2023-04-01', 880000,'Annual Increment'),
 ('NP0005','2023-01-09', 700000,'Hire')
) AS v (Code, EffDate, Salary, Reason)
JOIN dbo.Employee AS e ON e.EmployeeCode = v.Code;

-- 4) Attendance (LeaveTypeID only when Status = 'Leave'; LEFT JOIN keeps NULL rows)
INSERT INTO dbo.Attendance (EmployeeID, AttendanceDate, Status, LeaveTypeID)
SELECT e.EmployeeID, v.AttDate, v.Status, lt.LeaveTypeID
FROM (VALUES
 ('NP0004','2024-01-02','Present', NULL),
 ('NP0004','2024-01-03','WFH',     NULL),
 ('NP0004','2024-01-04','Leave',   'Sick'),
 ('NP0004','2024-01-05','Absent',  NULL)
) AS v (Code, AttDate, Status, LeaveName)
JOIN dbo.Employee AS e ON e.EmployeeCode = v.Code
LEFT JOIN dbo.LeaveType AS lt ON lt.LeaveTypeName = v.LeaveName;

-- 5) Performance reviews (reviewer = manager NP0003)
INSERT INTO dbo.PerformanceReview (EmployeeID, ReviewerID, ReviewYear, ReviewDate, Rating)
SELECT e.EmployeeID, r.EmployeeID, 2023, '2023-12-15', v.Rating
FROM (VALUES ('NP0004', 4), ('NP0005', 2)) AS v (Code, Rating)
JOIN dbo.Employee AS e ON e.EmployeeCode = v.Code
JOIN dbo.Employee AS r ON r.EmployeeCode = 'NP0003';

-- 6) One promotion: Software Engineer -> Senior Software Engineer
INSERT INTO dbo.Promotion
 (EmployeeID, PromotionDate, MovementType,
  OldJobRoleID, NewJobRoleID, OldDepartmentID, NewDepartmentID)
SELECT e.EmployeeID, '2024-04-01', 'Promotion',
       jo.JobRoleID, jn.JobRoleID, d.DepartmentID, d.DepartmentID
FROM dbo.Employee AS e
JOIN dbo.Department AS d  ON d.DepartmentName = 'Engineering'
JOIN dbo.JobRole    AS jo ON jo.DepartmentID = d.DepartmentID AND jo.JobTitle = 'Software Engineer'
JOIN dbo.JobRole    AS jn ON jn.DepartmentID = d.DepartmentID AND jn.JobTitle = 'Senior Software Engineer'
WHERE e.EmployeeCode = 'NP0004';

-- 7) One exit: Arjun leaves for better pay
INSERT INTO dbo.EmployeeExit (EmployeeID, ExitDate, ExitReasonID, Notes)
SELECT e.EmployeeID, '2024-03-31', r.ExitReasonID, N'Test record'
FROM dbo.Employee AS e
JOIN dbo.ExitReason AS r ON r.ReasonName = 'Better Pay'
WHERE e.EmployeeCode = 'NP0005';
GO