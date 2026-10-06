/* ==========================================================
   File    : 04_insert_data.sql
   Purpose : Permanent reference data (no employee data yet)
   ========================================================== */
USE HR_Analytics;
GO

-- ---------- Departments ----------
INSERT INTO dbo.Department (DepartmentName, CostCenterCode) VALUES
('Engineering',      'CC-ENG'),
('Sales',            'CC-SAL'),
('Marketing',        'CC-MKT'),
('HR',               'CC-HR'),
('Finance',          'CC-FIN'),
('Operations',       'CC-OPS'),
('Customer Support', 'CC-CS'),
('IT',               'CC-IT');

-- ---------- Locations ----------
INSERT INTO dbo.Location (City, State, Country) VALUES
('Bengaluru', 'Karnataka',     'India'),
('Hyderabad', 'Telangana',     'India'),
('Pune',      'Maharashtra',   'India'),
('Mumbai',    'Maharashtra',   'India'),
('Delhi',     'Delhi',         'India'),
('Lucknow',   'Uttar Pradesh', 'India');

-- ---------- Leave types ----------
INSERT INTO dbo.LeaveType (LeaveTypeName) VALUES
('Casual'), ('Sick'), ('Earned'), ('Unpaid');

-- ---------- Exit reasons ----------
INSERT INTO dbo.ExitReason (ReasonName, ReasonCategory) VALUES
('Better Pay',          'Voluntary'),
('Career Growth',       'Voluntary'),
('Relocation',          'Voluntary'),
('Poor Management',     'Voluntary'),
('Work-Life Balance',   'Voluntary'),
('Higher Studies',      'Voluntary'),
('Retirement',          'Voluntary'),
('Poor Performance',    'Involuntary'),
('Restructuring',       'Involuntary'),
('Misconduct',          'Involuntary');

-- ---------- Job roles (annual salary bands in INR) ----------
-- Department is looked up by NAME so we never hard-code IDs.
INSERT INTO dbo.JobRole (JobTitle, JobLevel, DepartmentID, MinSalary, MaxSalary)
SELECT v.JobTitle, v.JobLevel, d.DepartmentID, v.MinSalary, v.MaxSalary
FROM (VALUES
 ('Engineering','Software Engineer Trainee',1, 300000, 500000),
 ('Engineering','Software Engineer',        2, 500000, 900000),
 ('Engineering','Senior Software Engineer', 3, 900000,1600000),
 ('Engineering','Engineering Manager',      4,1600000,2600000),
 ('Engineering','Director of Engineering',  5,2600000,4000000),

 ('Sales','Sales Trainee',            1, 250000, 400000),
 ('Sales','Sales Executive',          2, 400000, 700000),
 ('Sales','Senior Sales Executive',   3, 700000,1200000),
 ('Sales','Sales Manager',            4,1200000,2000000),
 ('Sales','Regional Sales Head',      5,2000000,3500000),

 ('Marketing','Marketing Trainee',          1, 250000, 400000),
 ('Marketing','Marketing Executive',        2, 400000, 700000),
 ('Marketing','Senior Marketing Executive', 3, 700000,1200000),
 ('Marketing','Marketing Manager',          4,1200000,2000000),
 ('Marketing','Head of Marketing',          5,2000000,3200000),

 ('HR','HR Trainee',         1, 240000, 380000),
 ('HR','HR Executive',       2, 380000, 650000),
 ('HR','Senior HR Executive',3, 650000,1100000),
 ('HR','HR Manager',         4,1100000,1900000),
 ('HR','HR Head',            5,1900000,3000000),

 ('Finance','Finance Trainee',       1, 250000, 400000),
 ('Finance','Finance Analyst',       2, 420000, 750000),
 ('Finance','Senior Finance Analyst',3, 750000,1300000),
 ('Finance','Finance Manager',       4,1300000,2200000),
 ('Finance','Finance Head',          5,2200000,3500000),

 ('Operations','Operations Trainee',       1, 240000, 380000),
 ('Operations','Operations Executive',     2, 380000, 650000),
 ('Operations','Senior Operations Executive',3,650000,1100000),
 ('Operations','Operations Manager',       4,1100000,1900000),
 ('Operations','Head of Operations',       5,1900000,3200000),
 ('Operations','Chief Executive Officer',  6,4000000,8000000),

 ('Customer Support','Support Trainee',          1, 200000, 320000),
 ('Customer Support','Support Executive',        2, 320000, 520000),
 ('Customer Support','Senior Support Executive', 3, 520000, 850000),
 ('Customer Support','Support Manager',          4, 850000,1500000),
 ('Customer Support','Head of Customer Support', 5,1500000,2600000),

 ('IT','IT Support Trainee', 1, 240000, 380000),
 ('IT','IT Support Engineer',2, 380000, 700000),
 ('IT','Senior IT Engineer', 3, 700000,1250000),
 ('IT','IT Manager',         4,1250000,2100000),
 ('IT','Head of IT',         5,2100000,3400000)
) AS v (DepartmentName, JobTitle, JobLevel, MinSalary, MaxSalary)
JOIN dbo.Department AS d ON d.DepartmentName = v.DepartmentName;