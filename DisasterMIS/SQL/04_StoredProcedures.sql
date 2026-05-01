USE DisasterMIS;
GO

CREATE OR ALTER PROCEDURE sp_AuthenticateUser
    @Email NVARCHAR(100),
    @PasswordHash NVARCHAR(255)
AS
BEGIN
    SELECT u.UserID, u.FullName, u.Email, u.IsActive, ut.UserType, ut.UserTypeID
    FROM Users u
    INNER JOIN UserTypes ut ON u.UserTypeID = ut.UserTypeID
    WHERE u.Email = @Email AND u.PasswordHash = @PasswordHash AND u.IsActive = 1;
END
GO

CREATE OR ALTER PROCEDURE sp_AllocateResource
    @ResourceID INT,
    @ReportID INT,
    @Quantity INT,
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- UPDLOCK prevents concurrent allocation of the same resource
        DECLARE @CurrentStock INT;
        SELECT @CurrentStock = StockLevel
        FROM Resources WITH (UPDLOCK, ROWLOCK)
        WHERE ResourceID = @ResourceID;

        IF @CurrentStock < @Quantity
        BEGIN
            RAISERROR('Insufficient stock for this resource.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        INSERT INTO ResourceAllocations (ResourceID, ReportID, Quantity, Status, AllocationDate)
        VALUES (@ResourceID, @ReportID, @Quantity, 'Pending', GETDATE());

        UPDATE Resources
        SET StockLevel = StockLevel - @Quantity
        WHERE ResourceID = @ResourceID;

        INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp)
        VALUES (@UserID,
            (SELECT TableID FROM Tables WHERE AffectedTable = 'ResourceAllocations'),
            'INSERT', NULL,
            'Allocated ' + CAST(@Quantity AS NVARCHAR) + ' of ResourceID ' + CAST(@ResourceID AS NVARCHAR) + ' to ReportID ' + CAST(@ReportID AS NVARCHAR),
            GETDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_AssignRescueTeam
    @ReportID INT,
    @TeamID INT,
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- UPDLOCK prevents concurrent assignment of the same team
        DECLARE @CurrentStatus NVARCHAR(30);
        SELECT @CurrentStatus = AvailabilityStatus
        FROM RescueTeams WITH (UPDLOCK, ROWLOCK)
        WHERE TeamID = @TeamID;

        IF @CurrentStatus != 'Available'
        BEGIN
            RAISERROR('This rescue team is not available.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        INSERT INTO RescueAssignments (ReportID, TeamID, AssignedAt, Status)
        VALUES (@ReportID, @TeamID, GETDATE(), 'Assigned');

        -- Status moves to 'Assigned' — field officer confirms 'Busy' via sp_MarkTeamBusy
        UPDATE RescueTeams
        SET AvailabilityStatus = 'Assigned'
        WHERE TeamID = @TeamID;

        UPDATE EmergencyReports
        SET Status = 'Active'
        WHERE ReportID = @ReportID AND Status = 'Pending';

        INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp)
        VALUES (@UserID,
            (SELECT TableID FROM Tables WHERE AffectedTable = 'RescueAssignments'),
            'INSERT', NULL,
            'Assigned TeamID ' + CAST(@TeamID AS NVARCHAR) + ' to ReportID ' + CAST(@ReportID AS NVARCHAR),
            GETDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Field officer confirms team has deployed: Assigned => Busy
CREATE OR ALTER PROCEDURE sp_MarkTeamBusy
    @AssignmentID INT,
    @ReportID INT,
    @TeamID INT,
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE RescueAssignments
        SET Status = 'In Progress'
        WHERE AssignmentID = @AssignmentID AND ReportID = @ReportID AND TeamID = @TeamID
          AND Status = 'Assigned';

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('Assignment not found or already in progress.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        UPDATE RescueTeams
        SET AvailabilityStatus = 'Busy'
        WHERE TeamID = @TeamID;

        INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp)
        VALUES (@UserID,
            (SELECT TableID FROM Tables WHERE AffectedTable = 'RescueAssignments'),
            'UPDATE', 'Assigned',
            'In Progress: TeamID ' + CAST(@TeamID AS NVARCHAR),
            GETDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_CompleteAssignment
    @AssignmentID INT,
    @ReportID INT,
    @TeamID INT,
    @CompletionNotes NVARCHAR(500),
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @OldStatus NVARCHAR(30);
        SELECT @OldStatus = Status
        FROM RescueAssignments WITH (UPDLOCK, ROWLOCK)
        WHERE AssignmentID = @AssignmentID AND ReportID = @ReportID AND TeamID = @TeamID;

        IF @OldStatus IS NULL
        BEGIN
            RAISERROR('Assignment record not found.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        UPDATE RescueAssignments
        SET Status = 'Completed', CompletedAt = GETDATE(), CompletionNotes = @CompletionNotes
        WHERE AssignmentID = @AssignmentID AND ReportID = @ReportID AND TeamID = @TeamID;

        -- Restore team to 'Available' only if no other active assignments remain
        DECLARE @ActiveAssignments INT;
        SELECT @ActiveAssignments = COUNT(*)
        FROM RescueAssignments
        WHERE TeamID = @TeamID AND Status IN ('Assigned', 'In Progress');

        IF @ActiveAssignments = 0
        BEGIN
            UPDATE RescueTeams SET AvailabilityStatus = 'Available' WHERE TeamID = @TeamID;
        END

        INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp)
        VALUES (@UserID,
            (SELECT TableID FROM Tables WHERE AffectedTable = 'RescueAssignments'),
            'UPDATE', ISNULL(@OldStatus, 'In Progress'),
            'Completed: ' + ISNULL(@CompletionNotes, ''),
            GETDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_RecordFinancialTransaction
    @Amount DECIMAL(18,2),
    @Category NVARCHAR(50),
    @Description NVARCHAR(500),
    @EventID INT,
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO FinancialRecords (Amount, Category, Description, TransactionDate, EventID)
        VALUES (@Amount, @Category, @Description, GETDATE(), @EventID);

        INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp)
        VALUES (@UserID,
            (SELECT TableID FROM Tables WHERE AffectedTable = 'FinancialRecords'),
            'INSERT', NULL,
            @Category + ': ' + CAST(@Amount AS NVARCHAR) + ' - ' + ISNULL(@Description, ''),
            GETDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_ProcessApproval
    @ApprovalID INT,
    @RequesterID INT,
    @ApproverID INT,
    @Status NVARCHAR(30),
    @Notes NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE ApprovalWorkflow
        SET Status = @Status, ApproverID = @ApproverID, Notes = @Notes
        WHERE ApprovalID = @ApprovalID AND RequesterID = @RequesterID;

        IF @Status = 'Approved'
        BEGIN
            DECLARE @AllocationID INT;
            SELECT @AllocationID = AllocationID 
            FROM ApprovalWorkflow 
            WHERE ApprovalID = @ApprovalID AND RequesterID = @RequesterID;

            IF @AllocationID IS NOT NULL
            BEGIN
                UPDATE ResourceAllocations
                SET Status = 'Approved'
                WHERE AllocationID = @AllocationID;
            END
        END

        INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp)
        VALUES (@ApproverID,
            (SELECT TableID FROM Tables WHERE AffectedTable = 'ApprovalWorkflow'),
            'UPDATE', 'Pending',
            @Status + ': ' + ISNULL(@Notes, ''),
            GETDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_AdmitPatient
    @FirstName NVARCHAR(50),
    @LastName NVARCHAR(50),
    @Status NVARCHAR(30),
    @HospitalID INT,
    @BedNumber INT,
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @AvailableBeds INT;
        SELECT @AvailableBeds = h.TotalBeds - COUNT(a.PatientID)
        FROM Hospitals h
        LEFT JOIN Admits a ON h.HospitalID = a.HospitalID
        WHERE h.HospitalID = @HospitalID
        GROUP BY h.TotalBeds;

        IF @AvailableBeds <= 0
        BEGIN
            RAISERROR('No available beds in this hospital.', 16, 1);
            RETURN;
        END

        DECLARE @PatientID INT;
        INSERT INTO Patients (FirstName, LastName, Status)
        VALUES (@FirstName, @LastName, @Status);
        SET @PatientID = SCOPE_IDENTITY();

        INSERT INTO Admits (HospitalID, PatientID, BedNumber, AdmissionDate)
        VALUES (@HospitalID, @PatientID, @BedNumber, GETDATE());

        INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp)
        VALUES (@UserID,
            (SELECT TableID FROM Tables WHERE AffectedTable = 'Patients'),
            'INSERT', NULL,
            'Admitted ' + @FirstName + ' ' + @LastName + ' to HospitalID ' + CAST(@HospitalID AS NVARCHAR),
            GETDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_CreateEmergencyReport
    @Location NVARCHAR(200),
    @SeverityLevel INT,
    @EventID INT,
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO EmergencyReports (Location, SeverityLevel, Status, ReportTime, EventID, UserID)
        VALUES (@Location, @SeverityLevel, 'Pending', GETDATE(), @EventID, @UserID);

        INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp)
        VALUES (@UserID,
            (SELECT TableID FROM Tables WHERE AffectedTable = 'EmergencyReports'),
            'INSERT', NULL,
            'New report: ' + @Location + ', Severity ' + CAST(@SeverityLevel AS NVARCHAR),
            GETDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateEmergencyStatus
    @ReportID INT,
    @Status NVARCHAR(30),
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @OldStatus NVARCHAR(30);
        SELECT @OldStatus = Status FROM EmergencyReports WHERE ReportID = @ReportID;

        UPDATE EmergencyReports SET Status = @Status WHERE ReportID = @ReportID;

        INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp)
        VALUES (@UserID,
            (SELECT TableID FROM Tables WHERE AffectedTable = 'EmergencyReports'),
            'UPDATE', @OldStatus, @Status,
            GETDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_DeleteEmergencyReport
    @ReportID INT,
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @Location NVARCHAR(200);
        SELECT @Location = Location FROM EmergencyReports WHERE ReportID = @ReportID;

        DELETE FROM EmergencyReports WHERE ReportID = @ReportID;

        INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp)
        VALUES (@UserID,
            (SELECT TableID FROM Tables WHERE AffectedTable = 'EmergencyReports'),
            'DELETE',
            'ReportID ' + CAST(@ReportID AS NVARCHAR) + ': ' + ISNULL(@Location, ''),
            NULL,
            GETDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_CreateRescueTeam
    @TeamName NVARCHAR(100),
    @CurrentLocation NVARCHAR(200),
    @TeamTypeID INT,
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO RescueTeams (TeamName, CurrentLocation, AvailabilityStatus, TeamTypeID)
        VALUES (@TeamName, @CurrentLocation, 'Available', @TeamTypeID);

        INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp)
        VALUES (@UserID,
            (SELECT TableID FROM Tables WHERE AffectedTable = 'RescueTeams'),
            'INSERT', NULL,
            'Created team: ' + @TeamName,
            GETDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_AddResource
    @ResourceName NVARCHAR(100),
    @StockLevel INT,
    @ThresholdLevel INT,
    @ResourceTypeID INT,
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO Resources (ResourceName, StockLevel, ThresholdLevel, ResourceTypeID)
        VALUES (@ResourceName, @StockLevel, @ThresholdLevel, @ResourceTypeID);

        INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp)
        VALUES (@UserID,
            (SELECT TableID FROM Tables WHERE AffectedTable = 'Resources'),
            'INSERT', NULL,
            'Added resource: ' + @ResourceName + ', Stock: ' + CAST(@StockLevel AS NVARCHAR),
            GETDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateResourceStock
    @ResourceID INT,
    @AdditionalStock INT,
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @OldStock INT;
        SELECT @OldStock = StockLevel FROM Resources WHERE ResourceID = @ResourceID;

        UPDATE Resources SET StockLevel = StockLevel + @AdditionalStock WHERE ResourceID = @ResourceID;

        INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp)
        VALUES (@UserID,
            (SELECT TableID FROM Tables WHERE AffectedTable = 'Resources'),
            'UPDATE',
            'Stock: ' + CAST(@OldStock AS NVARCHAR),
            'Stock: ' + CAST(@OldStock + @AdditionalStock AS NVARCHAR),
            GETDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_ConsumeResource
    @AllocationID INT,
    @ResourceID INT,
    @ReportID INT,
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- trg_AuditResourceAllocationUpdate fires on this UPDATE
        UPDATE ResourceAllocations
        SET Status = 'Consumed'
        WHERE AllocationID = @AllocationID AND ResourceID = @ResourceID AND ReportID = @ReportID;

        INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp)
        VALUES (@UserID,
            (SELECT TableID FROM Tables WHERE AffectedTable = 'ResourceAllocations'),
            'UPDATE', NULL,
            'Consumed AllocationID ' + CAST(@AllocationID AS NVARCHAR),
            GETDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_UpdatePatientStatus
    @PatientID INT,
    @Status NVARCHAR(30),
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @OldStatus NVARCHAR(30);
        SELECT @OldStatus = Status FROM Patients WHERE PatientID = @PatientID;

        UPDATE Patients SET Status = @Status WHERE PatientID = @PatientID;

        INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp)
        VALUES (@UserID,
            (SELECT TableID FROM Tables WHERE AffectedTable = 'Patients'),
            'UPDATE', @OldStatus, @Status,
            GETDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_DischargePatient
    @PatientID INT,
    @HospitalID INT,
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @PatientName NVARCHAR(100);
        SELECT @PatientName = FirstName + ' ' + LastName FROM Patients WHERE PatientID = @PatientID;

        DELETE FROM Admits WHERE PatientID = @PatientID AND HospitalID = @HospitalID;

        INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp)
        VALUES (@UserID,
            (SELECT TableID FROM Tables WHERE AffectedTable = 'Admits'),
            'DELETE',
            'Discharged: ' + ISNULL(@PatientName, 'PatientID ' + CAST(@PatientID AS NVARCHAR)),
            NULL,
            GETDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_SubmitApprovalRequest
    @RequesterID INT,
    @RequestTypeID INT,
    @AllocationID INT = NULL,
    @Notes NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO ApprovalWorkflow (RequesterID, RequestTypeID, AllocationID, Status, Notes)
        VALUES (@RequesterID, @RequestTypeID, @AllocationID, 'Pending', @Notes);

        INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp)
        VALUES (@RequesterID,
            (SELECT TableID FROM Tables WHERE AffectedTable = 'ApprovalWorkflow'),
            'INSERT', NULL,
            'Approval request: TypeID ' + CAST(@RequestTypeID AS NVARCHAR) + ' - ' + ISNULL(@Notes, ''),
            GETDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_DeleteFinancialRecord
    @TransactionID INT,
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @Category NVARCHAR(50);
        DECLARE @Amount DECIMAL(18,2);
        SELECT @Category = Category, @Amount = Amount
        FROM FinancialRecords WHERE TransactionID = @TransactionID;

        -- trg_AuditFinancialDelete also fires on this DELETE
        DELETE FROM FinancialRecords WHERE TransactionID = @TransactionID;

        INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp)
        VALUES (@UserID,
            (SELECT TableID FROM Tables WHERE AffectedTable = 'FinancialRecords'),
            'DELETE',
            @Category + ': ' + CAST(@Amount AS NVARCHAR),
            NULL,
            GETDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
