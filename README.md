# Smart Disaster Response MIS

A full-stack enterprise Management Information System for coordinating disaster response operations — built with SQL Server, C# .NET, and ASP.NET Core.

---

## Overview

The system manages real-time coordination between emergency operators, field officers, warehouse managers, finance officers, and administrators during natural disasters (floods, earthquakes, urban fires). It handles high-volume transactions, role-based access control, automated database workflows, and MIS reporting.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | ASP.NET Core MVC / Razor Pages |
| Backend | C# .NET |
| Database | SQL Server |
| DB Management | SSMS (SQL Server Management Studio) |
| ORM / Data Access | ADO.NET + Entity Framework Core |
| Auth & RBAC | ASP.NET Core Identity |
| Charts / Dashboards | Chart.js |
| Password Hashing | BCrypt.Net-Next |

---

## Project Structure

```
DisasterMIS/
│
├── DisasterMIS.Web/                  # ASP.NET Core — controllers, views, static assets
│   ├── Controllers/                  # HTTP request handlers, one per module
│   ├── Views/                        # Razor Pages (.cshtml) per role/feature
│   ├── wwwroot/                      # CSS, JS, Chart.js assets
│   └── Program.cs                    # App startup, DI registration
│
├── DisasterMIS.Core/                 # Business logic, models, interfaces
│   ├── Models/                       # C# entity classes (EmergencyReport, RescueTeam…)
│   ├── DTOs/                         # Data Transfer Objects for API/view layer
│   ├── Interfaces/                   # IRepository, IService contracts
│   └── Services/                     # Business rules, RBAC enforcement, workflows
│
├── DisasterMIS.Data/                 # Data access layer
│   ├── Repositories/                 # ADO.NET repository implementations
│   ├── AppDbContext.cs               # EF Core DbContext (if used)
│   └── ConnectionFactory.cs         # SqlConnection factory
│
└── DisasterMIS.Database/             # All SQL files (submit these as deliverables)
    ├── Tables/                       # CREATE TABLE scripts
    ├── StoredProcedures/             # sp_AllocateResource, sp_AssignTeam…
    ├── Triggers/                     # trg_UpdateTeamStatus, trg_LogTransaction…
    ├── Views/                        # vw_FinanceOfficerView, vw_FieldOfficerView…
    ├── Indexes/                      # IX_Reports_DisasterType…
    └── SeedData/                     # Sample data for testing
```

---

## Database Design

### Core Tables

| Table | Purpose |
|---|---|
| `EmergencyReports` | Citizen-submitted incident reports with location, type, severity |
| `RescueTeams` | Team records with type, location, availability status |
| `RescueAssignments` | Links teams to reports; tracks assignment history |
| `Resources` | Inventory (food, water, medicine, shelter equipment) per warehouse |
| `ResourceAllocations` | Dispatched vs consumed resource tracking |
| `Hospitals` | Bed capacity, admitted patients, critical cases |
| `FinancialRecords` | Donations, expenses, procurement costs per disaster |
| `Users` | System users with hashed passwords |
| `Roles` | Administrator, Emergency Operator, Field Officer, Warehouse Manager, Finance Officer |
| `ApprovalWorkflows` | Pending/Approved/Rejected requests with approval history |
| `AuditLogs` | Timestamped log of all user actions and data modifications |

### Key Database Features

**Triggers (event-driven automation)**
- Auto-update resource stock after allocation or dispatch
- Change rescue team status on assignment (`Available → Assigned → Busy → Completed`)
- Log all financial transactions into audit tables
- Enforce business rules (e.g. prevent negative inventory)

**Views (role-specific data visibility)**
- `vw_FinanceOfficerView` — financial data only, no operational details
- `vw_FieldOfficerView` — active reports and assigned teams
- `vw_AdminDashboard` — aggregated system-wide statistics

**Indexes (performance optimization)**
- Indexed on: `DisasterType`, `Location`, `ResourceType`, `TransactionDate`, `SeverityLevel`
- Composite indexes for frequently joined queries
- Query latency comparison: indexed vs non-indexed (documented in report)

**Transactions (ACID)**
- All multi-step operations wrapped in `BEGIN TRANSACTION / COMMIT / ROLLBACK`
- Examples: resource allocation, team assignment, financial approvals
- Rollback on failure with proper error logging

---

## User Roles & Access

| Role | Access |
|---|---|
| Administrator | Full system access, user management, all reports |
| Emergency Operator | Create/manage reports, assign teams |
| Field Officer | View assigned reports, update status |
| Warehouse Manager | Manage inventory, process resource requests |
| Finance Officer | Record and view financial transactions |

RBAC is enforced at two levels — the database (via views restricting columns/rows) and the application layer (`[Authorize(Roles = "...")]` on controllers).

---

## Getting Started

### Prerequisites

- Visual Studio 2022
- SQL Server (Developer or Express edition)
- SSMS (SQL Server Management Studio)
- .NET 8 SDK

### Setup

**1. Clone the repository**
```bash
git clone https://github.com/your-username/DisasterMIS.git
cd DisasterMIS
```

**2. Create the database**

Open SSMS, connect to your SQL Server instance, then run the scripts in order:
```
DisasterMIS.Database/Tables/
DisasterMIS.Database/Views/
DisasterMIS.Database/StoredProcedures/
DisasterMIS.Database/Triggers/
DisasterMIS.Database/Indexes/
DisasterMIS.Database/SeedData/
```

**3. Configure the connection string**

In `DisasterMIS.Web/appsettings.json`:
```json
{
  "ConnectionStrings": {
    "DisasterMIS": "Server=localhost;Database=DisasterMIS;Trusted_Connection=True;TrustServerCertificate=True;"
  }
}
```

**4. Run the application**
```bash
cd DisasterMIS.Web
dotnet run
```
Or press **F5** in Visual Studio.

---

## Key Implementation Notes

### Calling Stored Procedures from C\#
```csharp
using var conn = new SqlConnection(_connectionString);
await conn.OpenAsync();
using var cmd = new SqlCommand("sp_AllocateResource", conn);
cmd.CommandType = CommandType.StoredProcedure;
cmd.Parameters.AddWithValue("@ResourceID", resourceId);
cmd.Parameters.AddWithValue("@Quantity", qty);
await cmd.ExecuteNonQueryAsync();
```

### Transaction Handling
Transactions for multi-step operations are handled inside stored procedures using `BEGIN TRANSACTION / COMMIT / ROLLBACK`. This keeps ACID guarantees at the database level regardless of application-layer failures.

### Password Security
All passwords are hashed using BCrypt before storage — never stored as plain text. Authentication is managed via ASP.NET Core Identity.

---

## Team

| Name         |  Std-ID  |
|--------------|----------|
| Abdul Rehman | 24I-3001 |
| Tahir Habib  | 24I-3087 |
| Talha Sami   | 24I-3118 |

---
