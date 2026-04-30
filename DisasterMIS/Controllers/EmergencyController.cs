using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Data.SqlClient;
using System.Security.Claims;
using DisasterMIS.Data;

namespace DisasterMIS.Controllers
{
    [Authorize]
    public class EmergencyController : Controller
    {
        public IActionResult Index(string status = "", string location = "", int severity = 0)
        {
            string query = @"SELECT er.ReportID, er.Location, er.SeverityLevel, er.Status, er.ReportTime,
                de.DisasterType, u.FullName AS ReportedBy
                FROM EmergencyReports er
                INNER JOIN DisasterEvents de ON er.EventID = de.EventID
                INNER JOIN Users u ON er.UserID = u.UserID
                WHERE 1=1";

            var parameters = new List<SqlParameter>();

            if (!string.IsNullOrEmpty(status))
            {
                query += " AND er.Status = @Status";
                parameters.Add(new SqlParameter("@Status", status));
            }
            if (!string.IsNullOrEmpty(location))
            {
                query += " AND er.Location LIKE @Location";
                parameters.Add(new SqlParameter("@Location", "%" + location + "%"));
            }
            if (severity > 0)
            {
                query += " AND er.SeverityLevel = @Severity";
                parameters.Add(new SqlParameter("@Severity", severity));
            }

            query += " ORDER BY er.ReportTime DESC";

            ViewBag.Reports = DbHelper.ExecuteQuery(query, parameters.ToArray());
            ViewBag.DisasterEvents = DbHelper.ExecuteQuery("SELECT * FROM DisasterEvents");
            ViewBag.Status = status;
            ViewBag.Location = location;
            ViewBag.Severity = severity;
            return View();
        }

        public IActionResult Create()
        {
            ViewBag.DisasterEvents = DbHelper.ExecuteQuery("SELECT * FROM DisasterEvents");
            return View();
        }

        [HttpPost]
        public IActionResult Create(string location, int severityLevel, int eventID)
        {
            int userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);

            DbHelper.ExecuteNonQuery(
                "INSERT INTO EmergencyReports (Location, SeverityLevel, Status, ReportTime, EventID, UserID) VALUES (@Location, @Severity, 'Pending', GETDATE(), @EventID, @UserID)",
                new SqlParameter("@Location", location),
                new SqlParameter("@Severity", severityLevel),
                new SqlParameter("@EventID", eventID),
                new SqlParameter("@UserID", userId));

            return RedirectToAction("Index");
        }

        public IActionResult Details(int id)
        {
            var report = DbHelper.ExecuteQuery(
                @"SELECT er.*, de.DisasterType, u.FullName AS ReportedBy
                FROM EmergencyReports er
                INNER JOIN DisasterEvents de ON er.EventID = de.EventID
                INNER JOIN Users u ON er.UserID = u.UserID
                WHERE er.ReportID = @ReportID",
                new SqlParameter("@ReportID", id));

            var assignments = DbHelper.ExecuteQuery(
                @"SELECT ra.AssignmentID, ra.AssignedAt, ra.CompletedAt, ra.Status, ra.CompletionNotes,
                rt.TeamName, tt.TeamType
                FROM RescueAssignments ra
                INNER JOIN RescueTeams rt ON ra.TeamID = rt.TeamID
                INNER JOIN TeamTypes tt ON rt.TeamTypeID = tt.TeamTypeID
                WHERE ra.ReportID = @ReportID",
                new SqlParameter("@ReportID", id));

            var allocations = DbHelper.ExecuteQuery(
                @"SELECT ra.AllocationID, ra.Quantity, ra.Status, ra.AllocationDate,
                r.ResourceName, rtype.ResourceType
                FROM ResourceAllocations ra
                INNER JOIN Resources r ON ra.ResourceID = r.ResourceID
                INNER JOIN ResourceTypes rtype ON r.ResourceTypeID = rtype.ResourceTypeID
                WHERE ra.ReportID = @ReportID",
                new SqlParameter("@ReportID", id));

            if (report.Rows.Count == 0)
                return NotFound();

            ViewBag.Report = report.Rows[0];
            ViewBag.Assignments = assignments;
            ViewBag.Allocations = allocations;
            return View();
        }

        [HttpPost]
        public IActionResult UpdateStatus(int reportID, string status)
        {
            DbHelper.ExecuteNonQuery(
                "UPDATE EmergencyReports SET Status = @Status WHERE ReportID = @ReportID",
                new SqlParameter("@Status", status),
                new SqlParameter("@ReportID", reportID));

            return RedirectToAction("Details", new { id = reportID });
        }

        [Authorize(Roles = "Administrator")]
        public IActionResult Delete(int id)
        {
            DbHelper.ExecuteNonQuery("DELETE FROM EmergencyReports WHERE ReportID = @ID", new SqlParameter("@ID", id));
            return RedirectToAction("Index");
        }
    }
}
