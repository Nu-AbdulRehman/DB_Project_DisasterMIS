USE DisasterMIS;
GO

INSERT INTO UserTypes (UserType) VALUES
('Administrator'),
('Emergency Operator'),
('Field Officer'),
('Warehouse Manager'),
('Finance Officer');

INSERT INTO Users (FullName, Email, PasswordHash, IsActive, UserTypeID) VALUES
('Admin User', 'admin@disaster.gov', 'hashed_admin123', 1, 1),
('Sarah Operator', 'sarah@disaster.gov', 'hashed_sarah123', 1, 2),
('Ahmed Field', 'ahmed@disaster.gov', 'hashed_ahmed123', 1, 3),
('Ali Warehouse', 'ali@disaster.gov', 'hashed_ali123', 1, 4),
('Fatima Finance', 'fatima@disaster.gov', 'hashed_fatima123', 1, 5);

INSERT INTO DisasterEvents (DisasterType) VALUES
('Flood'),
('Earthquake'),
('Urban Fire'),
('Cyclone'),
('Landslide');

INSERT INTO TeamTypes (TeamType) VALUES
('Medical'),
('Fire'),
('Rescue');

INSERT INTO RescueTeams (TeamName, CurrentLocation, AvailabilityStatus, TeamTypeID) VALUES
('Alpha Medical Unit', 'Karachi Central', 'Available', 1),
('Bravo Fire Squad', 'Lahore Cantt', 'Available', 2),
('Charlie Rescue Team', 'Islamabad F-8', 'Available', 3),
('Delta Medical Unit', 'Peshawar Saddar', 'Available', 1),
('Echo Fire Brigade', 'Quetta City', 'Busy', 2),
('Foxtrot SAR Team', 'Multan Central', 'Available', 3);

INSERT INTO ResourceTypes (ResourceType) VALUES
('Food'),
('Water'),
('Medicine'),
('Shelter Equipment');

INSERT INTO Resources (ResourceName, StockLevel, ThresholdLevel, ResourceTypeID) VALUES
('Rice Bags (50kg)', 500, 50, 1),
('Canned Food Packs', 1200, 100, 1),
('Water Bottles (1.5L)', 3000, 200, 2),
('Water Purification Tablets', 5000, 500, 2),
('First Aid Kits', 400, 40, 3),
('Antibiotics Pack', 800, 80, 3),
('Paracetamol Strips', 2000, 200, 3),
('Tents (4-person)', 150, 20, 4),
('Blankets', 1000, 100, 4),
('Sleeping Bags', 600, 60, 4);

INSERT INTO Warehouses (Name, Location) VALUES
('Central Warehouse Karachi', 'Karachi Port Area'),
('Northern Depot Islamabad', 'Islamabad I-9 Industrial'),
('Lahore Relief Center', 'Lahore Johar Town'),
('Peshawar Emergency Store', 'Peshawar University Road');

INSERT INTO WarehouseStock (WarehouseID, ResourceID, Stock) VALUES
(1, 1, 150), (1, 2, 300), (1, 3, 800), (1, 4, 1200),
(1, 5, 100), (1, 6, 200), (1, 7, 500), (1, 8, 40),
(2, 1, 120), (2, 2, 350), (2, 3, 700), (2, 5, 100),
(2, 8, 50), (2, 9, 300), (2, 10, 200),
(3, 1, 130), (3, 3, 800), (3, 6, 200), (3, 9, 400),
(4, 1, 100), (4, 2, 250), (4, 5, 100), (4, 7, 500), (4, 10, 200);

INSERT INTO Hospitals (Name, Location, TotalBeds) VALUES
('Jinnah Hospital Karachi', 'Karachi Saddar', 500),
('PIMS Islamabad', 'Islamabad G-8', 400),
('Mayo Hospital Lahore', 'Lahore Anarkali', 600),
('Lady Reading Hospital', 'Peshawar City', 350),
('Civil Hospital Quetta', 'Quetta Jinnah Road', 250);

INSERT INTO Patients (FirstName, LastName, Status) VALUES
('Usman', 'Khan', 'Critical'),
('Ayesha', 'Malik', 'Stable'),
('Hassan', 'Raza', 'Recovering'),
('Zainab', 'Ali', 'Critical'),
('Bilal', 'Ahmed', 'Stable'),
('Nadia', 'Shah', 'Recovering'),
('Omar', 'Farooq', 'Critical'),
('Sana', 'Qureshi', 'Stable');

INSERT INTO Admits (HospitalID, PatientID, BedNumber, AdmissionDate) VALUES
(1, 1, 101, '2026-04-15 08:30:00'),
(1, 2, 102, '2026-04-16 10:15:00'),
(2, 3, 201, '2026-04-15 14:00:00'),
(2, 4, 202, '2026-04-17 09:45:00'),
(3, 5, 301, '2026-04-16 11:30:00'),
(4, 6, 401, '2026-04-18 07:00:00'),
(4, 7, 402, '2026-04-18 13:20:00'),
(5, 8, 501, '2026-04-19 16:00:00');

INSERT INTO EmergencyReports (Location, SeverityLevel, Status, ReportTime, EventID, UserID) VALUES
('Karachi Korangi', 4, 'Active', '2026-04-20 06:30:00', 1, 2),
('Lahore Gulberg', 3, 'Active', '2026-04-20 07:15:00', 1, 2),
('Islamabad F-10', 5, 'Resolved', '2026-04-18 14:00:00', 2, 3),
('Peshawar Hayatabad', 4, 'Active', '2026-04-21 09:00:00', 3, 3),
('Quetta Satellite Town', 5, 'Active', '2026-04-22 03:45:00', 2, 2),
('Multan Cantt', 2, 'Pending', '2026-04-22 11:30:00', 1, 3),
('Karachi DHA', 3, 'Resolved', '2026-04-19 08:00:00', 3, 2),
('Islamabad G-11', 4, 'Active', '2026-04-23 06:00:00', 4, 2),
('Lahore Model Town', 1, 'Pending', '2026-04-23 10:00:00', 5, 3),
('Peshawar Ring Road', 5, 'Active', '2026-04-24 02:30:00', 2, 2);

INSERT INTO RescueAssignments (ReportID, TeamID, AssignedAt, CompletedAt, Status, CompletionNotes) VALUES
(1, 1, '2026-04-20 07:00:00', NULL, 'In Progress', NULL),
(1, 3, '2026-04-20 07:15:00', NULL, 'In Progress', NULL),
(3, 3, '2026-04-18 14:30:00', '2026-04-19 10:00:00', 'Completed', 'All residents evacuated safely'),
(4, 2, '2026-04-21 09:30:00', NULL, 'Assigned', NULL),
(5, 4, '2026-04-22 04:00:00', NULL, 'In Progress', NULL),
(7, 2, '2026-04-19 08:30:00', '2026-04-19 18:00:00', 'Completed', 'Fire contained and extinguished');

INSERT INTO ResourceAllocations (ResourceID, ReportID, Quantity, Status, AllocationDate) VALUES
(1, 1, 30, 'Dispatched', '2026-04-20 08:00:00'),
(3, 1, 100, 'Dispatched', '2026-04-20 08:00:00'),
(5, 1, 10, 'Dispatched', '2026-04-20 08:30:00'),
(8, 5, 20, 'Pending', '2026-04-22 05:00:00'),
(9, 5, 50, 'Approved', '2026-04-22 05:00:00'),
(1, 4, 15, 'Dispatched', '2026-04-21 10:00:00'),
(6, 3, 20, 'Delivered', '2026-04-18 15:00:00');

INSERT INTO FinancialRecords (Amount, Category, Description, TransactionDate, EventID) VALUES
(500000.00, 'Donation', 'Corporate donation from ABC Corp', '2026-04-15 10:00:00', 1),
(1200000.00, 'Donation', 'Government emergency fund release', '2026-04-16 09:00:00', 2),
(75000.00, 'Expense', 'Fuel for rescue vehicles', '2026-04-20 12:00:00', 1),
(250000.00, 'Procurement', 'Emergency medical supplies purchase', '2026-04-18 14:00:00', 2),
(45000.00, 'Expense', 'Temporary shelter setup costs', '2026-04-21 08:00:00', 3),
(800000.00, 'Donation', 'International relief fund', '2026-04-22 06:00:00', 2),
(120000.00, 'Procurement', 'Food rations bulk order', '2026-04-19 11:00:00', 1),
(30000.00, 'Expense', 'Communication equipment repair', '2026-04-23 09:00:00', 4);

INSERT INTO RequestTypes (RequestType) VALUES
('Resource Distribution'),
('Rescue Deployment'),
('Financial Approval');

INSERT INTO ApprovalWorkflow (RequesterID, ApproverID, RequestTypeID, AllocationID, Status, Notes) VALUES
(3, 1, 1, 4, 'Pending', 'Need 20 tents for Quetta earthquake survivors'),
(3, 1, 2, NULL, 'Approved', 'Deploy Delta Medical to Peshawar fire'),
(5, 1, 3, NULL, 'Approved', 'Approve emergency medical supplies procurement'),
(4, 1, 1, 5, 'Pending', 'Request 50 blankets for Quetta'),
(3, NULL, 2, NULL, 'Pending', 'Request rescue team for Lahore Model Town');

INSERT INTO Tables (AffectedTable) VALUES
('Users'), ('EmergencyReports'), ('RescueTeams'), ('RescueAssignments'),
('Resources'), ('ResourceAllocations'), ('WarehouseStock'),
('Hospitals'), ('Patients'), ('Admits'),
('FinancialRecords'), ('ApprovalWorkflow');

INSERT INTO AuditLog (UserID, TableID, Action, OldValue, NewValue, Timestamp) VALUES
(1, 2, 'INSERT', NULL, 'New report: Karachi Korangi, Severity 4', '2026-04-20 06:30:00'),
(1, 4, 'INSERT', NULL, 'Assigned Alpha Medical to Report #1', '2026-04-20 07:00:00'),
(1, 6, 'INSERT', NULL, 'Allocated 30 Rice Bags to Report #1', '2026-04-20 08:00:00'),
(1, 11, 'INSERT', NULL, 'Donation: 500000 from ABC Corp', '2026-04-15 10:00:00'),
(1, 3, 'UPDATE', 'Available', 'Busy', '2026-04-20 07:00:00');
