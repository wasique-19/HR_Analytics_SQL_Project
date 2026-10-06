/* ==========================================================
   File    : 03_constraints.sql
   Purpose : Adds foreign keys and CHECK constraints
   Run     : After 02_create_tables.sql
   ========================================================== */

-- ---------- FOREIGN KEYS ----------

ALTER TABLE dbo.JobRole
    ADD CONSTRAINT FK_JobRole_Department
    FOREIGN KEY (DepartmentID) REFERENCES dbo.Department (DepartmentID);

ALTER TABLE dbo.Employee
    ADD CONSTRAINT FK_Employee_Department FOREIGN KEY (DepartmentID) REFERENCES dbo.Department (DepartmentID),
        CONSTRAINT FK_Employee_JobRole    FOREIGN KEY (JobRoleID)    REFERENCES dbo.JobRole (JobRoleID),
        CONSTRAINT FK_Employee_Location   FOREIGN KEY (LocationID)   REFERENCES dbo.Location (LocationID),
        CONSTRAINT FK_Employee_Manager    FOREIGN KEY (ManagerID)    REFERENCES dbo.Employee (EmployeeID);

ALTER TABLE dbo.SalaryHistory
    ADD CONSTRAINT FK_SalaryHistory_Employee
    FOREIGN KEY (EmployeeID) REFERENCES dbo.Employee (EmployeeID);

ALTER TABLE dbo.Attendance
    ADD CONSTRAINT FK_Attendance_Employee  FOREIGN KEY (EmployeeID)  REFERENCES dbo.Employee (EmployeeID),
        CONSTRAINT FK_Attendance_LeaveType FOREIGN KEY (LeaveTypeID) REFERENCES dbo.LeaveType (LeaveTypeID);

ALTER TABLE dbo.PerformanceReview
    ADD CONSTRAINT FK_PerformanceReview_Employee FOREIGN KEY (EmployeeID) REFERENCES dbo.Employee (EmployeeID),
        CONSTRAINT FK_PerformanceReview_Reviewer FOREIGN KEY (ReviewerID) REFERENCES dbo.Employee (EmployeeID);

ALTER TABLE dbo.Promotion
    ADD CONSTRAINT FK_Promotion_Employee      FOREIGN KEY (EmployeeID)      REFERENCES dbo.Employee (EmployeeID),
        CONSTRAINT FK_Promotion_OldJobRole    FOREIGN KEY (OldJobRoleID)    REFERENCES dbo.JobRole (JobRoleID),
        CONSTRAINT FK_Promotion_NewJobRole    FOREIGN KEY (NewJobRoleID)    REFERENCES dbo.JobRole (JobRoleID),
        CONSTRAINT FK_Promotion_OldDepartment FOREIGN KEY (OldDepartmentID) REFERENCES dbo.Department (DepartmentID),
        CONSTRAINT FK_Promotion_NewDepartment FOREIGN KEY (NewDepartmentID) REFERENCES dbo.Department (DepartmentID);

ALTER TABLE dbo.EmployeeExit
    ADD CONSTRAINT FK_EmployeeExit_Employee   FOREIGN KEY (EmployeeID)   REFERENCES dbo.Employee (EmployeeID),
        CONSTRAINT FK_EmployeeExit_ExitReason FOREIGN KEY (ExitReasonID) REFERENCES dbo.ExitReason (ExitReasonID);

-- ---------- CHECK CONSTRAINTS ----------

ALTER TABLE dbo.JobRole
    ADD CONSTRAINT CK_JobRole_Level      CHECK (JobLevel BETWEEN 1 AND 6),
        CONSTRAINT CK_JobRole_MinSalary  CHECK (MinSalary > 0),
        CONSTRAINT CK_JobRole_SalaryBand CHECK (MaxSalary > MinSalary);

ALTER TABLE dbo.Employee
    ADD CONSTRAINT CK_Employee_Gender         CHECK (Gender IN ('M','F','O')),
        CONSTRAINT CK_Employee_EmploymentType CHECK (EmploymentType IN ('Full-Time','Contract','Intern')),
        CONSTRAINT CK_Employee_HireDate       CHECK (HireDate >= '2010-01-01'),
        CONSTRAINT CK_Employee_MinHireAge     CHECK (HireDate >= DATEADD(YEAR, 18, DateOfBirth)),
        CONSTRAINT CK_Employee_NotOwnManager  CHECK (ManagerID IS NULL OR ManagerID <> EmployeeID);

ALTER TABLE dbo.SalaryHistory
    ADD CONSTRAINT CK_SalaryHistory_Salary CHECK (BaseSalary > 0),
        CONSTRAINT CK_SalaryHistory_Reason CHECK (ChangeReason IN ('Hire','Annual Increment','Promotion','Correction'));

ALTER TABLE dbo.Attendance
    ADD CONSTRAINT CK_Attendance_Status CHECK (Status IN ('Present','Absent','Leave','WFH')),
        CONSTRAINT CK_Attendance_LeaveLink CHECK (
            (Status = 'Leave' AND LeaveTypeID IS NOT NULL)
         OR (Status <> 'Leave' AND LeaveTypeID IS NULL));

ALTER TABLE dbo.PerformanceReview
    ADD CONSTRAINT CK_PerformanceReview_Rating   CHECK (Rating BETWEEN 1 AND 5),
        CONSTRAINT CK_PerformanceReview_Year     CHECK (ReviewYear BETWEEN 2010 AND 2100),
        CONSTRAINT CK_PerformanceReview_Reviewer CHECK (ReviewerID <> EmployeeID);

ALTER TABLE dbo.Promotion
    ADD CONSTRAINT CK_Promotion_MovementType CHECK (MovementType IN ('Promotion','Lateral Transfer')),
        CONSTRAINT CK_Promotion_Changed CHECK (OldJobRoleID <> NewJobRoleID OR OldDepartmentID <> NewDepartmentID);

ALTER TABLE dbo.ExitReason
    ADD CONSTRAINT CK_ExitReason_Category CHECK (ReasonCategory IN ('Voluntary','Involuntary'));