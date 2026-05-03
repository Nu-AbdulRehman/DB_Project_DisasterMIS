USE DisasterMIS;
GO

-- TEST 1: Location filter (uses IX_EmergencyReports_Location)

PRINT '=== TEST 1A: Location filter WITHOUT index (forced table scan) ===';
SET STATISTICS TIME ON;
SET STATISTICS IO ON;

SELECT * FROM EmergencyReports WITH (INDEX(0))
WHERE Location LIKE '%Karachi%';

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

PRINT '=== TEST 1B: Location filter WITH index ===';
SET STATISTICS TIME ON;
SET STATISTICS IO ON;

SELECT * FROM EmergencyReports
WHERE Location LIKE '%Karachi%';

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- TEST 2: Severity level filter (uses IX_EmergencyReports_SeverityLevel)

PRINT '=== TEST 2A: Severity filter WITHOUT index (forced table scan) ===';
SET STATISTICS TIME ON;
SET STATISTICS IO ON;

SELECT * FROM EmergencyReports WITH (INDEX(0))
WHERE SeverityLevel >= 4;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

PRINT '=== TEST 2B: Severity filter WITH index ===';
SET STATISTICS TIME ON;
SET STATISTICS IO ON;

SELECT * FROM EmergencyReports
WHERE SeverityLevel >= 4;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- TEST 3: Financial records date range

PRINT '=== TEST 3A: Financial date range WITHOUT index ===';
SET STATISTICS TIME ON;
SET STATISTICS IO ON;

SELECT * FROM FinancialRecords WITH (INDEX(0))
WHERE TransactionDate BETWEEN '2026-04-15' AND '2026-04-25';

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

PRINT '=== TEST 3B: Financial date range WITH index ===';
SET STATISTICS TIME ON;
SET STATISTICS IO ON;

SELECT * FROM FinancialRecords
WHERE TransactionDate BETWEEN '2026-04-15' AND '2026-04-25';

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- TEST 4: View vs Direct table query (ActiveEmergencies)

PRINT '=== TEST 4A: Active emergencies via DIRECT table query ===';
SET STATISTICS TIME ON;
SET STATISTICS IO ON;

SELECT er.ReportID, er.Location, er.SeverityLevel, er.Status, er.ReportTime,
    de.DisasterType, u.FullName
FROM EmergencyReports er
INNER JOIN DisasterEvents de ON er.EventID = de.EventID
INNER JOIN Users u ON er.UserID = u.UserID
WHERE er.Status IN ('Pending', 'Active');

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

PRINT '=== TEST 4B: Active emergencies via VIEW (vw_ActiveEmergencies) ===';
SET STATISTICS TIME ON;
SET STATISTICS IO ON;

SELECT * FROM vw_ActiveEmergencies;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- TEST 5: View vs Direct table query (HospitalCapacity)

PRINT '=== TEST 5A: Hospital capacity via DIRECT aggregation ===';
SET STATISTICS TIME ON;
SET STATISTICS IO ON;

SELECT h.HospitalID, h.Name, h.Location, h.TotalBeds,
    h.TotalBeds - COUNT(a.PatientID) AS AvailableBeds,
    SUM(CASE WHEN p.Status = 'Critical' THEN 1 ELSE 0 END) AS CriticalCases
FROM Hospitals h
LEFT JOIN Admits a ON h.HospitalID = a.HospitalID
LEFT JOIN Patients p ON a.PatientID = p.PatientID
GROUP BY h.HospitalID, h.Name, h.Location, h.TotalBeds;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

PRINT '=== TEST 5B: Hospital capacity via VIEW (vw_HospitalCapacity) ===';
SET STATISTICS TIME ON;
SET STATISTICS IO ON;

SELECT * FROM vw_HospitalCapacity;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- TEST 6: Composite index on RescueAssignments 

PRINT '=== TEST 6A: Active rescue assignments WITHOUT composite index ===';
SET STATISTICS TIME ON;
SET STATISTICS IO ON;

SELECT ra.*, rt.TeamName, er.Location
FROM RescueAssignments ra WITH (INDEX(0))
INNER JOIN RescueTeams rt ON ra.TeamID = rt.TeamID
INNER JOIN EmergencyReports er ON ra.ReportID = er.ReportID
WHERE ra.Status IN ('Assigned', 'In Progress');

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

PRINT '=== TEST 6B: Active rescue assignments WITH composite index ===';
SET STATISTICS TIME ON;
SET STATISTICS IO ON;

SELECT ra.*, rt.TeamName, er.Location
FROM RescueAssignments ra
INNER JOIN RescueTeams rt ON ra.TeamID = rt.TeamID
INNER JOIN EmergencyReports er ON ra.ReportID = er.ReportID
WHERE ra.Status IN ('Assigned', 'In Progress');

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO