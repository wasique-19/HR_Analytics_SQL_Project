/* ==========================================================
   Project : Employee Performance & HR Analytics System
   File    : 02_create_tables.sql
   Purpose : Creates all 11 tables (structure, PKs, UNIQUE, DEFAULTs)
   Notes   : FKs and CHECKs are added in 03_constraints.sql
   ========================================================== */
USE HR_Analytics;
GO

-- ---------- 1. LOOKUP / MASTER TABLES ----------

CREATE TABLE dbo.Department (
    DepartmentID    INT IDENTITY(1,1)  NOT NULL,
    DepartmentName  NVARCHAR(100)      NOT NULL,
    CostCenterCode  VARCHAR(10)        NOT NULL,
    CONSTRAINT PK_Department PRIMARY KEY (DepartmentID),
    CONSTRAINT UQ_Department_Name UNIQUE (DepartmentName),
    CONSTRAINT UQ_Department_CostCenter UNIQUE (CostCenterCode)
);

CREATE TABLE dbo.JobRole (
    JobRoleID     INT IDENTITY(1,1)  NOT NULL,
    JobTitle      NVARCHAR(100)      NOT NULL,
    JobLevel      TINYINT            NOT NULL,
    DepartmentID  INT                NOT NULL,
    MinSalary     DECIMAL(12,2)      NOT NULL,
    MaxSalary     DECIMAL(12,2)      NOT NULL,
    CONSTRAINT PK_JobRole PRIMARY KEY (JobRoleID),
    CONSTRAINT UQ_JobRole_Dept_Title UNIQUE (DepartmentID, JobTitle)
);

CREATE TABLE dbo.Location (
    LocationID  INT IDENTITY(1,1)  NOT NULL,
    City        NVARCHAR(100)      NOT NULL,
    State       NVARCHAR(100)      NULL,
    Country     NVARCHAR(100)      NOT NULL,
    CONSTRAINT PK_Location PRIMARY KEY (LocationID),
    CONSTRAINT UQ_Location_City_Country UNIQUE (City, Country)
);

CREATE TABLE dbo.LeaveType (
    LeaveTypeID    INT IDENTITY(1,1)  NOT NULL,
    LeaveTypeName  VARCHAR(30)        NOT NULL,
    CONSTRAINT PK_LeaveType PRIMARY KEY (LeaveTypeID),
    CONSTRAINT UQ_LeaveType_Name UNIQUE (LeaveTypeName)
);

CREATE TABLE dbo.ExitReason (
    ExitReasonID    INT IDENTITY(1,1)  NOT NULL,
    ReasonName      VARCHAR(60)        NOT NULL,
    ReasonCategory  VARCHAR(20)        NOT NULL,
    CONSTRAINT PK_ExitReason PRIMARY KEY (ExitReasonID),
    CONSTRAINT UQ_ExitReason_Name UNIQUE (ReasonName)
);

-- ---------- 2. CORE TABLE ----------

CREATE TABLE dbo.Employee (
    EmployeeID      INT IDENTITY(1,1)  NOT NULL,
    EmployeeCode    VARCHAR(10)        NOT NULL,   -- business ID, e.g. NP0001
    FirstName       NVARCHAR(50)       NOT NULL,
    LastName        NVARCHAR(50)       NOT NULL,
    Gender          CHAR(1)            NOT NULL,
    DateOfBirth     DATE               NOT NULL,
    Email           VARCHAR(150)       NOT NULL,
    HireDate        DATE               NOT NULL,
    EmploymentType  VARCHAR(20)        NOT NULL
        CONSTRAINT DF_Employee_EmploymentType DEFAULT ('Full-Time'),
    DepartmentID    INT                NOT NULL,
    JobRoleID       INT                NOT NULL,
    LocationID      INT                NOT NULL,
    ManagerID       INT                NULL,       -- NULL for the top executive
    CONSTRAINT PK_Employee PRIMARY KEY (EmployeeID),
    CONSTRAINT UQ_Employee_Code  UNIQUE (EmployeeCode),
    CONSTRAINT UQ_Employee_Email UNIQUE (Email)
);

-- ---------- 3. TRANSACTION TABLES ----------

CREATE TABLE dbo.SalaryHistory (
    SalaryHistoryID  INT IDENTITY(1,1)  NOT NULL,
    EmployeeID       INT                NOT NULL,
    EffectiveDate    DATE               NOT NULL,
    BaseSalary       DECIMAL(12,2)      NOT NULL,
    ChangeReason     VARCHAR(30)        NOT NULL,
    CONSTRAINT PK_SalaryHistory PRIMARY KEY (SalaryHistoryID),
    CONSTRAINT UQ_SalaryHistory_Emp_Date UNIQUE (EmployeeID, EffectiveDate)
);

CREATE TABLE dbo.Attendance (
    AttendanceID    BIGINT IDENTITY(1,1)  NOT NULL,
    EmployeeID      INT                   NOT NULL,
    AttendanceDate  DATE                  NOT NULL,
    Status          VARCHAR(15)           NOT NULL,
    LeaveTypeID     INT                   NULL,    -- only when Status = 'Leave'
    CONSTRAINT PK_Attendance PRIMARY KEY (AttendanceID),
    CONSTRAINT UQ_Attendance_Emp_Date UNIQUE (EmployeeID, AttendanceDate)
);

CREATE TABLE dbo.PerformanceReview (
    ReviewID     INT IDENTITY(1,1)  NOT NULL,
    EmployeeID   INT                NOT NULL,
    ReviewerID   INT                NOT NULL,
    ReviewYear   SMALLINT           NOT NULL,
    ReviewDate   DATE               NOT NULL,
    Rating       TINYINT            NOT NULL,
    CONSTRAINT PK_PerformanceReview PRIMARY KEY (ReviewID),
    CONSTRAINT UQ_PerformanceReview_Emp_Year UNIQUE (EmployeeID, ReviewYear)
);

CREATE TABLE dbo.Promotion (
    PromotionID       INT IDENTITY(1,1)  NOT NULL,
    EmployeeID        INT                NOT NULL,
    PromotionDate     DATE               NOT NULL,
    MovementType      VARCHAR(20)        NOT NULL,
    OldJobRoleID      INT                NOT NULL,
    NewJobRoleID      INT                NOT NULL,
    OldDepartmentID   INT                NOT NULL,
    NewDepartmentID   INT                NOT NULL,
    CONSTRAINT PK_Promotion PRIMARY KEY (PromotionID)
);

CREATE TABLE dbo.EmployeeExit (
    ExitID        INT IDENTITY(1,1)  NOT NULL,
    EmployeeID    INT                NOT NULL,
    ExitDate      DATE               NOT NULL,
    ExitReasonID  INT                NOT NULL,
    Notes         NVARCHAR(300)      NULL,
    CONSTRAINT PK_EmployeeExit PRIMARY KEY (ExitID),
    CONSTRAINT UQ_EmployeeExit_Employee UNIQUE (EmployeeID)   -- one exit per person
);