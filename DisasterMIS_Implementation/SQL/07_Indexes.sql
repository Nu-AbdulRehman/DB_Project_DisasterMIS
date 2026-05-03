USE DisasterMIS;
GO

CREATE NONCLUSTERED INDEX IX_EmergencyReports_Location ON EmergencyReports(Location);
CREATE NONCLUSTERED INDEX IX_EmergencyReports_SeverityLevel ON EmergencyReports(SeverityLevel);
CREATE NONCLUSTERED INDEX IX_EmergencyReports_EventID_Status ON EmergencyReports(EventID, Status);
CREATE NONCLUSTERED INDEX IX_EmergencyReports_Status ON EmergencyReports(Status);
CREATE NONCLUSTERED INDEX IX_FinancialRecords_TransactionDate ON FinancialRecords(TransactionDate);
CREATE NONCLUSTERED INDEX IX_FinancialRecords_Category ON FinancialRecords(Category);
CREATE NONCLUSTERED INDEX IX_Resources_ResourceTypeID ON Resources(ResourceTypeID);
CREATE NONCLUSTERED INDEX IX_RescueAssignments_ReportID_TeamID ON RescueAssignments(ReportID, TeamID);
CREATE NONCLUSTERED INDEX IX_RescueAssignments_Status ON RescueAssignments(Status);
CREATE NONCLUSTERED INDEX IX_AuditLog_Timestamp ON AuditLog(Timestamp);
CREATE NONCLUSTERED INDEX IX_AuditLog_UserID ON AuditLog(UserID);
CREATE NONCLUSTERED INDEX IX_ApprovalWorkflow_Status ON ApprovalWorkflow(Status);
CREATE NONCLUSTERED INDEX IX_ResourceAllocations_Status ON ResourceAllocations(Status);
