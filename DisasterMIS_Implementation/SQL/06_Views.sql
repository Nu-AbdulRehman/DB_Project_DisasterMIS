USE DisasterMIS;
GO

CREATE OR ALTER VIEW vw_ActiveEmergencies AS
SELECT er.ReportID, er.Location, er.SeverityLevel, er.Status, er.ReportTime,
    de.DisasterType, u.FullName AS ReportedBy
FROM EmergencyReports er
INNER JOIN DisasterEvents de ON er.EventID = de.EventID
INNER JOIN Users u ON er.UserID = u.UserID
WHERE er.Status IN ('Pending', 'Active');
GO

CREATE OR ALTER VIEW vw_TeamAvailability AS
SELECT rt.TeamID, rt.TeamName, rt.CurrentLocation, rt.AvailabilityStatus,
    tt.TeamType
FROM RescueTeams rt
INNER JOIN TeamTypes tt ON rt.TeamTypeID = tt.TeamTypeID;
GO

CREATE OR ALTER VIEW vw_ResourceInventory AS
SELECT r.ResourceID, r.ResourceName, r.StockLevel, r.ThresholdLevel,
    rtype.ResourceType,
    CASE WHEN r.StockLevel <= r.ThresholdLevel THEN 'Low Stock' ELSE 'OK' END AS StockStatus
FROM Resources r
INNER JOIN ResourceTypes rtype ON r.ResourceTypeID = rtype.ResourceTypeID;
GO

CREATE OR ALTER VIEW vw_HospitalCapacity AS
SELECT h.HospitalID, h.Name, h.Location, h.TotalBeds,
    h.TotalBeds - COUNT(a.PatientID) AS AvailableBeds,
    SUM(CASE WHEN p.Status = 'Critical' THEN 1 ELSE 0 END) AS CriticalCases
FROM Hospitals h
LEFT JOIN Admits a ON h.HospitalID = a.HospitalID
LEFT JOIN Patients p ON a.PatientID = p.PatientID
GROUP BY h.HospitalID, h.Name, h.Location, h.TotalBeds;
GO

CREATE OR ALTER VIEW vw_FinancialSummary AS
SELECT fr.TransactionID, fr.Amount, fr.Category, fr.Description, fr.TransactionDate,
    de.DisasterType
FROM FinancialRecords fr
INNER JOIN DisasterEvents de ON fr.EventID = de.EventID;
GO

CREATE OR ALTER VIEW vw_ApprovalStatus AS
SELECT aw.ApprovalID, aw.RequesterID, aw.ApproverID, aw.AllocationID,
    aw.Status, aw.Notes,
    req.FullName AS RequesterName,
    app.FullName AS ApproverName,
    rt.RequestType
FROM ApprovalWorkflow aw
INNER JOIN Users req ON aw.RequesterID = req.UserID
LEFT JOIN Users app ON aw.ApproverID = app.UserID
INNER JOIN RequestTypes rt ON aw.RequestTypeID = rt.RequestTypeID;
GO

CREATE OR ALTER VIEW vw_AuditTrail AS
SELECT al.LogID, al.UserID, al.Action, al.OldValue, al.NewValue, al.Timestamp,
    u.FullName AS UserName,
    t.AffectedTable
FROM AuditLog al
LEFT JOIN Users u ON al.UserID = u.UserID
LEFT JOIN Tables t ON al.TableID = t.TableID;
GO

CREATE OR ALTER VIEW vw_FinanceOfficerView AS
SELECT fr.TransactionID, fr.Amount, fr.Category, fr.Description, fr.TransactionDate,
    de.DisasterType
FROM FinancialRecords fr
INNER JOIN DisasterEvents de ON fr.EventID = de.EventID;
GO

CREATE OR ALTER VIEW vw_FieldOfficerView AS
SELECT er.ReportID, er.Location, er.SeverityLevel, er.Status, er.ReportTime,
    de.DisasterType
FROM EmergencyReports er
INNER JOIN DisasterEvents de ON er.EventID = de.EventID;
GO

CREATE OR ALTER VIEW vw_WarehouseInventory AS
SELECT w.WarehouseID, w.Name AS WarehouseName, w.Location,
    r.ResourceName, ws.Stock, rtype.ResourceType
FROM WarehouseStock ws
INNER JOIN Warehouses w ON ws.WarehouseID = w.WarehouseID
INNER JOIN Resources r ON ws.ResourceID = r.ResourceID
INNER JOIN ResourceTypes rtype ON r.ResourceTypeID = rtype.ResourceTypeID;
GO
