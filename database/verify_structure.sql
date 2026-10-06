USE HR_Analytics;
GO

-- A) Row counts for all 11 tables
SELECT t.name AS TableName, SUM(p.rows) AS RowCnt
FROM sys.tables AS t
JOIN sys.partitions AS p ON p.object_id = t.object_id AND p.index_id IN (0,1)
GROUP BY t.name
ORDER BY t.name;

-- B) Constraint inventory by type
SELECT type_desc AS ConstraintType, COUNT(*) AS Total
FROM sys.objects
WHERE type IN ('PK','UQ','F','C','D')
GROUP BY type_desc
ORDER BY type_desc;

-- C) End-to-end relationship test: does every FK path join correctly?
SELECT e.EmployeeCode,
       e.FirstName + ' ' + e.LastName AS EmployeeName,
       d.DepartmentName,
       j.JobTitle,
       l.City,
       m.FirstName + ' ' + m.LastName AS ManagerName
FROM dbo.Employee AS e
JOIN dbo.Department AS d ON d.DepartmentID = e.DepartmentID
JOIN dbo.JobRole    AS j ON j.JobRoleID    = e.JobRoleID
JOIN dbo.Location   AS l ON l.LocationID   = e.LocationID
LEFT JOIN dbo.Employee AS m ON m.EmployeeID = e.ManagerID   -- LEFT: CEO has no manager
ORDER BY e.EmployeeCode;