USE DisasterMIS;
GO

CREATE OR ALTER TRIGGER trg_PreventNegativeInventory
ON Resources
AFTER UPDATE
AS
BEGIN
    IF EXISTS (SELECT 1 FROM inserted WHERE StockLevel < 0)
    BEGIN
        RAISERROR('Stock level cannot go below zero.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

CREATE OR ALTER TRIGGER trg_UpdateTeamStatusOnAssignment
ON RescueAssignments
AFTER INSERT
AS
BEGIN
    -- Sets 'Assigned' — sp_MarkTeamBusy transitions to 'Busy' when field officer deploys
    UPDATE RescueTeams
    SET AvailabilityStatus = 'Assigned'
    WHERE TeamID IN (SELECT TeamID FROM inserted)
      AND AvailabilityStatus = 'Available';
END
GO

CREATE OR ALTER TRIGGER trg_UpdateTeamStatusOnCompletion
ON RescueAssignments
AFTER UPDATE
AS
BEGIN
    IF UPDATE(Status)
    BEGIN
        DECLARE @TeamID INT;
        DECLARE team_cursor CURSOR FOR
            SELECT DISTINCT TeamID FROM inserted WHERE Status = 'Completed';
        OPEN team_cursor;
        FETCH NEXT FROM team_cursor INTO @TeamID;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM RescueAssignments 
                WHERE TeamID = @TeamID AND Status IN ('Assigned', 'In Progress')
            )
            BEGIN
                UPDATE RescueTeams SET AvailabilityStatus = 'Available' WHERE TeamID = @TeamID;
            END
            FETCH NEXT FROM team_cursor INTO @TeamID;
        END
        CLOSE team_cursor;
        DEALLOCATE team_cursor;
    END
END
GO

CREATE OR ALTER TRIGGER trg_AuditFinancialInsert
ON FinancialRecords
AFTER INSERT
AS
BEGIN
    INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp)
    SELECT 1,
        (SELECT TableID FROM Tables WHERE AffectedTable = 'FinancialRecords'),
        'INSERT', NULL,
        i.Category + ': ' + CAST(i.Amount AS NVARCHAR) + ' - ' + ISNULL(i.Description, ''),
        GETDATE()
    FROM inserted i;
END
GO

CREATE OR ALTER TRIGGER trg_AuditFinancialUpdate
ON FinancialRecords
AFTER UPDATE
AS
BEGIN
    INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp)
    SELECT 1,
        (SELECT TableID FROM Tables WHERE AffectedTable = 'FinancialRecords'),
        'UPDATE',
        d.Category + ': ' + CAST(d.Amount AS NVARCHAR),
        i.Category + ': ' + CAST(i.Amount AS NVARCHAR),
        GETDATE()
    FROM inserted i
    INNER JOIN deleted d ON i.TransactionID = d.TransactionID;
END
GO

CREATE OR ALTER TRIGGER trg_AuditFinancialDelete
ON FinancialRecords
AFTER DELETE
AS
BEGIN
    INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp)
    SELECT 1,
        (SELECT TableID FROM Tables WHERE AffectedTable = 'FinancialRecords'),
        'DELETE',
        d.Category + ': ' + CAST(d.Amount AS NVARCHAR) + ' - ' + ISNULL(d.Description, ''),
        NULL,
        GETDATE()
    FROM deleted d;
END
GO

CREATE OR ALTER TRIGGER trg_LowStockAlert
ON Resources
AFTER UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM inserted i
        WHERE i.StockLevel <= i.ThresholdLevel AND i.StockLevel > 0
    )
    BEGIN
        PRINT 'WARNING: Low stock detected for one or more resources.';
    END
END
GO

-- Audit trigger for resource allocation status changes (Dispatched -> Consumed)
CREATE OR ALTER TRIGGER trg_AuditResourceAllocationUpdate
ON ResourceAllocations
AFTER UPDATE
AS
BEGIN
    IF UPDATE(Status)
    BEGIN
        INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp)
        SELECT 1,
            (SELECT TableID FROM Tables WHERE AffectedTable = 'ResourceAllocations'),
            'UPDATE',
            'Status: ' + d.Status + ', Qty: ' + CAST(d.Quantity AS NVARCHAR),
            'Status: ' + i.Status + ', Qty: ' + CAST(i.Quantity AS NVARCHAR),
            GETDATE()
        FROM inserted i
        INNER JOIN deleted d ON i.AllocationID = d.AllocationID
            AND i.ResourceID = d.ResourceID
            AND i.ReportID = d.ReportID;
    END
END
GO
