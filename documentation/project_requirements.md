Functional & Technical Requirements

Functional requirements (what the system does):

FR1: Store employee master data with department, job role, and manager.
FR2: Maintain salary history (not just current salary).
FR3: Record daily attendance and leave.
FR4: Record periodic performance reviews.
FR5: Track promotions and transfers.
FR6: Capture exits with reason and date.
FR7: Provide queries and views for all KPIs.
FR8: Provide data-quality checks.


Technical requirements:

TR1: SQL Server 2019+ and T-SQL.
TR2: Database in at least 3rd Normal Form.
TR3: Primary and foreign keys on all tables, plus CHECK/UNIQUE/DEFAULT constraints.
TR4: Consistent naming convention (decided in Day 3).
TR5: All scripts re-runnable and commented.
TR6: Dataset of roughly 500 employees, 12–24 months of attendance, and 2–3 years of reviews.
TR7: Indexes on frequently joined and filtered columns.
TR8: Version control with Git.


Define the Company Profile and Assumptions

Document the fictional context so your data is internally consistent:

Company: NorthPeak Technologies, about 500 employees
Departments: Engineering, Sales, Marketing, HR, Finance, Operations, Customer Support, IT
Period covered: January 2022 – December 2025
Rating scale: 1 (Poor) to 5 (Outstanding), reviewed annually
Currency: INR (or whichever you prefer; decide once and stay consistent)


Identify Stakeholders
Stakeholder	Interest	What they need
CHRO / HR Head	Strategy	Attrition, workforce trends, cost
HR Business Partners	Department-level support	Department comparisons, at-risk groups
Department Managers	Team productivity	Team performance and attendance
Compensation Team	Pay fairness	Salary distribution, pay gaps
Finance	Budget	Salary cost, cost of attrition
You (Data Analyst)	Delivery	Clean data, accurate queries


Define the Scope
In scope	Out of scope
Employee master data	Payroll tax calculations
Departments, job roles, managers	Recruitment/applicant tracking
Salary history	Real-time data feeds
Daily attendance & leave	Front-end dashboards (Power BI)
Performance reviews	Machine learning models
Promotions & transfers	Employee personal sensitive data (health, etc.)


Define the Objective

Split it into one main objective and several measurable sub-objectives:

Main: Build a SQL Server-based HR analytics system that converts raw HR data into actionable workforce insights.
Sub-objectives:
Centralize employee, department, salary, attendance, performance, and promotion data in a normalized database.
Ensure data quality through validation and cleaning.
Calculate HR KPIs (attrition, absenteeism, performance, pay equity).
Identify the drivers of attrition and low performance.
Deliver recommendations supported by SQL evidence.


Write the Problem Statement

A good problem statement has the pattern: who is affected → what the problem is → what it costs → what we need. Here's a draft to adapt:

NorthPeak Technologies, a 500-employee company, stores HR data in disconnected spreadsheets. HR leadership cannot reliably measure employee performance, identify attrition drivers, or evaluate compensation fairness. This causes avoidable turnover, inconsistent promotion decisions, and reactive rather than proactive workforce planning. A centralized, queryable SQL database with analytical reporting is needed to support data-driven HR decisions.