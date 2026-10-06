USE HR_Analytics;
GO
SET NOCOUNT ON;

-- Test 1: Rating outside 1-5
BEGIN TRY
    INSERT INTO dbo.PerformanceReview (EmployeeID, ReviewerID, ReviewYear, ReviewDate, Rating)
    SELECT e.EmployeeID, r.EmployeeID, 2030, '2030-12-01', 9
    FROM dbo.Employee e JOIN dbo.Employee r ON r.EmployeeCode = 'NP0003'
    WHERE e.EmployeeCode = 'NP0004';
    PRINT 'Test 1 FAILED TO BLOCK';
END TRY
BEGIN CATCH PRINT 'Test 1 blocked: ' + ERROR_MESSAGE(); END CATCH;

-- Test 2: Duplicate attendance for the same employee and date
BEGIN TRY
    INSERT INTO dbo.Attendance (EmployeeID, AttendanceDate, Status)
    SELECT EmployeeID, '2024-01-02', 'Present' FROM dbo.Employee WHERE EmployeeCode = 'NP0004';
    PRINT 'Test 2 FAILED TO BLOCK';
END TRY
BEGIN CATCH PRINT 'Test 2 blocked: ' + ERROR_MESSAGE(); END CATCH;

-- Test 3: Status = 'Leave' but no leave type
BEGIN TRY
    INSERT INTO dbo.Attendance (EmployeeID, AttendanceDate, Status, LeaveTypeID)
    SELECT EmployeeID, '2024-01-08', 'Leave', NULL FROM dbo.Employee WHERE EmployeeCode = 'NP0004';
    PRINT 'Test 3 FAILED TO BLOCK';
END TRY
BEGIN CATCH PRINT 'Test 3 blocked: ' + ERROR_MESSAGE(); END CATCH;

-- Test 4: Orphan foreign key (employee 99999 does not exist)
BEGIN TRY
    INSERT INTO dbo.SalaryHistory (EmployeeID, EffectiveDate, BaseSalary, ChangeReason)
    VALUES (99999, '2024-01-01', 500000, 'Hire');
    PRINT 'Test 4 FAILED TO BLOCK';
END TRY
BEGIN CATCH PRINT 'Test 4 blocked: ' + ERROR_MESSAGE(); END CATCH;

-- Test 5: Employee set as their own manager
BEGIN TRY
    UPDATE dbo.Employee SET ManagerID = EmployeeID WHERE EmployeeCode = 'NP0004';
    PRINT 'Test 5 FAILED TO BLOCK';
END TRY
BEGIN CATCH PRINT 'Test 5 blocked: ' + ERROR_MESSAGE(); END CATCH;

-- Test 6: Salary band where max < min
BEGIN TRY
    INSERT INTO dbo.JobRole (JobTitle, JobLevel, DepartmentID, MinSalary, MaxSalary)
    SELECT 'Bad Role', 2, DepartmentID, 900000, 500000 FROM dbo.Department WHERE DepartmentName = 'IT';
    PRINT 'Test 6 FAILED TO BLOCK';
END TRY
BEGIN CATCH PRINT 'Test 6 blocked: ' + ERROR_MESSAGE(); END CATCH;