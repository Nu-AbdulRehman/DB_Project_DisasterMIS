using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Data.SqlClient;
using System.Security.Claims;
using DisasterMIS.Data;

namespace DisasterMIS.Controllers
{
    [Authorize]
    public class DashboardController : Controller
    {
        public IActionResult Index()
        {
            string role = User.FindFirst(ClaimTypes.Role)?.Value;
            int userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);

            var emergencyCount = DbHelper.ExecuteScalar("SELECT COUNT(*) FROM EmergencyReports WHERE Status IN ('Pending','Active')");
            var teamCount = DbHelper.ExecuteScalar("SELECT COUNT(*) FROM RescueTeams WHERE AvailabilityStatus = 'Available'");
            var lowStockCount = DbHelper.ExecuteScalar("SELECT COUNT(*) FROM Resources WHERE StockLevel <= ThresholdLevel");
            var pendingApprovals = DbHelper.ExecuteScalar("SELECT COUNT(*) FROM ApprovalWorkflow WHERE Status = 'Pending'");
            var totalDonations = DbHelper.ExecuteScalar("SELECT ISNULL(SUM(Amount),0) FROM FinancialRecords WHERE Category = 'Donation'");
            var totalExpenses = DbHelper.ExecuteScalar("SELECT ISNULL(SUM(Amount),0) FROM FinancialRecords WHERE Category IN ('Expense','Procurement')");
            var totalHospitalBeds = DbHelper.ExecuteScalar("SELECT ISNULL(SUM(TotalBeds),0) FROM Hospitals");
            var occupiedBeds = DbHelper.ExecuteScalar("SELECT COUNT(*) FROM Admits");

            ViewBag.Role = role;
            ViewBag.EmergencyCount = emergencyCount;
            ViewBag.TeamCount = teamCount;
            ViewBag.LowStockCount = lowStockCount;
            ViewBag.PendingApprovals = pendingApprovals;
            ViewBag.TotalDonations = totalDonations;
            ViewBag.TotalExpenses = totalExpenses;
            ViewBag.TotalHospitalBeds = totalHospitalBeds;
            ViewBag.OccupiedBeds = occupiedBeds;

            var recentReports = DbHelper.ExecuteQuery(
                "SELECT TOP 5 * FROM vw_ActiveEmergencies ORDER BY ReportTime DESC");
            ViewBag.RecentReports = recentReports;

            // Role-scoped views
            if (role == "Field Officer" || role == "Emergency Operator")
                ViewBag.RoleView = DbHelper.ExecuteQuery(
                    "SELECT TOP 5 * FROM vw_FieldOfficerView ORDER BY ReportTime DESC");
            else if (role == "Finance Officer")
                ViewBag.RoleView = DbHelper.ExecuteQuery(
                    "SELECT TOP 5 * FROM vw_FinanceOfficerView ORDER BY TransactionDate DESC");

            var severityData = DbHelper.ExecuteQuery(
                "SELECT SeverityLevel, COUNT(*) AS Count FROM EmergencyReports GROUP BY SeverityLevel ORDER BY SeverityLevel");
            ViewBag.SeverityData = severityData;

            var categoryData = DbHelper.ExecuteQuery(
                "SELECT Category, SUM(Amount) AS Total FROM FinancialRecords GROUP BY Category");
            ViewBag.CategoryData = categoryData;

            var disasterData = DbHelper.ExecuteQuery(
                "SELECT de.DisasterType, COUNT(*) AS Count FROM EmergencyReports er " +
                "INNER JOIN DisasterEvents de ON er.EventID = de.EventID GROUP BY de.DisasterType");
            ViewBag.DisasterData = disasterData;

            return View();
        }
    }
}
