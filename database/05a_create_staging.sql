/* ==========================================================
   Project : Employee Performance & HR Analytics System
   File    : 05a_create_staging.sql
   Purpose : Creates the 'stg' schema and 6 RAW staging tables.
   Why     : Raw files are messy. Staging tables have NO constraints
             and use text columns, so every row loads - even bad ones.
             We find the bad rows with SQL (Day 5 profile) and fix them (Day 6).
   Re-run  : Safe. Drops and recreates the staging tables each time.
   ========================================================== */
USE HR_Analytics;
GO

IF SCHEMA_ID('stg') IS NULL EXEC('CREATE SCHEMA stg');
GO

DROP TABLE IF EXISTS stg.Employee_Raw;
DROP TABLE IF EXISTS stg.SalaryHistory_Raw;
DROP TABLE IF EXISTS stg.Attendance_Raw;
DROP TABLE IF EXISTS stg.PerformanceReview_Raw;
DROP TABLE IF EXISTS stg.Promotion_Raw;
DROP TABLE IF EXISTS stg.EmployeeExit_Raw;
GO

CREATE TABLE stg.Employee_Raw (
    EmployeeCode   NVARCHAR(200) NULL,
    FirstName      NVARCHAR(200) NULL,
    LastName       NVARCHAR(200) NULL,
    Gender         NVARCHAR(200) NULL,
    DateOfBirth    NVARCHAR(200) NULL,
    Email          NVARCHAR(200) NULL,
    HireDate       NVARCHAR(200) NULL,
    EmploymentType NVARCHAR(200) NULL,
    DepartmentName NVARCHAR(200) NULL,
    JobTitle       NVARCHAR(200) NULL,
    City           NVARCHAR(200) NULL,
    ManagerCode    NVARCHAR(200) NULL
);

CREATE TABLE stg.SalaryHistory_Raw (
    EmployeeCode  NVARCHAR(200) NULL,
    EffectiveDate NVARCHAR(200) NULL,
    BaseSalary    NVARCHAR(200) NULL,
    ChangeReason  NVARCHAR(200) NULL
);

CREATE TABLE stg.Attendance_Raw (
    EmployeeCode   NVARCHAR(200) NULL,
    AttendanceDate NVARCHAR(200) NULL,
    Status         NVARCHAR(200) NULL,
    LeaveType      NVARCHAR(200) NULL
);

CREATE TABLE stg.PerformanceReview_Raw (
    EmployeeCode NVARCHAR(200) NULL,
    ReviewerCode NVARCHAR(200) NULL,
    ReviewYear   NVARCHAR(200) NULL,
    ReviewDate   NVARCHAR(200) NULL,
    Rating       NVARCHAR(200) NULL
);

CREATE TABLE stg.Promotion_Raw (
    EmployeeCode  NVARCHAR(200) NULL,
    PromotionDate NVARCHAR(200) NULL,
    MovementType  NVARCHAR(200) NULL,
    OldJobTitle   NVARCHAR(200) NULL,
    NewJobTitle   NVARCHAR(200) NULL,
    OldDepartment NVARCHAR(200) NULL,
    NewDepartment NVARCHAR(200) NULL
);

CREATE TABLE stg.EmployeeExit_Raw (
    EmployeeCode NVARCHAR(200) NULL,
    ExitDate     NVARCHAR(200) NULL,
    ExitReason   NVARCHAR(200) NULL,
    Notes        NVARCHAR(500) NULL
);
GO
