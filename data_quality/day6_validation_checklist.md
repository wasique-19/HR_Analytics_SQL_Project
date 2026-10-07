# Data Validation Checklist (Day 6)

Re-run `validation_checks.sql` after every data load. All rows must read PASS (or be explained).

| # | Check | Table | Rule | Method | Expected |
|---|---|---|---|---|---|
| A | Reconciliation | all 6 | staging rows = loaded + rejected | validation_checks.sql, section A | Unaccounted = 0 |
| 01 | Single top node | Employee | exactly one NULL ManagerID | section C | 1 |
| 02 | Manager seniority | Employee | manager hired no later than report | section C | 0 |
| 03 | Exit vs hire | EmployeeExit | ExitDate >= HireDate | section C | 0 |
| 04 | Attendance window | Attendance | between hire and exit | section C | 0 |
| 05 | Reviewer | PerformanceReview | reviewer = employee's manager | section C | 0 |
| 06 | Review vs exit | PerformanceReview | ReviewDate <= ExitDate | section C | 0 |
| 07 | Promotion vs role | Promotion | latest NewJobRole = current role | section C | 0 |
| 08 | Promotion level | Promotion | level goes up | section C | 0 |
| 09-10 | Salary vs band | SalaryHistory | current salary within band (-0% / +5%) | section C | 0 |
| 11-12 | Known gaps | SalaryHistory | caused by quarantined rows | section C | 1 and 2 |
| 13 | Active headcount | Employee | no exit record | section C | 446 |

## Cleaning decisions (policy)
| Problem | Decision | Why |
|---|---|---|
| Case / spaces / spelling variants | FIX | the correct value is certain |
| dd/mm/yyyy dates | FIX (style 103) | the format is unambiguous in this file |
| '8,50,000' salaries | FIX (remove commas) | value is certain |
| Blank e-mail | IMPUTE (name + code) | column is NOT NULL UNIQUE; flagged as placeholder |
| Exact duplicates | KEEP FIRST | copies carry no new information |
| Conflicting duplicate reviews | QUARANTINE ALL | cannot know which rating is true |
| Blank / out-of-range rating | QUARANTINE | guessing would bias performance KPIs |
| Zero / negative / outlier salary | QUARANTINE | impossible or implausible |
| Orphan employee codes | QUARANTINE | no employee to attach to |
| Attendance after exit / before hire | QUARANTINE | impossible |
| Leave type on a non-leave day | QUARANTINE | ambiguous: wrong status or wrong leave type? |
