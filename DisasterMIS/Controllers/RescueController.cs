using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Data.SqlClient;
using System.Security.Claims;
using DisasterMIS.Data;

namespace DisasterMIS.Controllers
{
    [Authorize]
    public class RescueController : Controller
    {
        public IActionResult Index()
        {
            ViewBag.Teams = DbHelper.ExecuteQuery(
                "SELECT * FROM vw_TeamAvailability ORDER BY AvailabilityStatus, TeamName");

            ViewBag.Assignments = DbHelper.ExecuteQuery(
                @"SELECT ra.AssignmentID, ra.ReportID, ra.TeamID, ra.AssignedAt, ra.CompletedAt, ra.Status,
                rt.TeamName, er.Location, er.SeverityLevel
                FROM RescueAssignments ra
                INNER JOIN RescueTeams rt ON ra.TeamID = rt.TeamID
                INNER JOIN EmergencyReports er ON ra.ReportID = er.ReportID
                WHERE ra.Status != 'Completed'
                ORDER BY ra.AssignedAt DESC");

            return View();
        }

        public IActionResult Create()
        {
            ViewBag.TeamTypes = DbHelper.ExecuteQuery("SELECT * FROM TeamTypes");
            return View();
        }

        [HttpPost]
        public IActionResult Create(string teamName, string currentLocation, int teamTypeID)
        {
            int userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);

            DbHelper.ExecuteStoredProcedureNonQuery("sp_CreateRescueTeam",
                new SqlParameter("@TeamName", teamName),
                new SqlParameter("@CurrentLocation", currentLocation),
                new SqlParameter("@TeamTypeID", teamTypeID),
                new SqlParameter("@UserID", userId));

            return RedirectToAction("Index");
        }

        public IActionResult Assign()
        {
            ViewBag.Reports = DbHelper.ExecuteQuery(
                @"SELECT er.ReportID, er.Location, er.SeverityLevel, de.DisasterType
                FROM EmergencyReports er
                INNER JOIN DisasterEvents de ON er.EventID = de.EventID
                WHERE er.Status IN ('Pending','Active')
                ORDER BY er.SeverityLevel DESC");

            ViewBag.Teams = DbHelper.ExecuteQuery(
                "SELECT * FROM vw_TeamAvailability WHERE AvailabilityStatus = 'Available'");

            return View();
        }

        [HttpPost]
        public IActionResult Assign(int reportID, int teamID)
        {
            int userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);

            try
            {
                DbHelper.ExecuteStoredProcedureNonQuery("sp_AssignRescueTeam",
                    new SqlParameter("@ReportID", reportID),
                    new SqlParameter("@TeamID", teamID),
                    new SqlParameter("@UserID", userId));

                TempData["Success"] = "Team assigned successfully.";
            }
            catch (Exception ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction("Index");
        }

        [HttpPost]
        public IActionResult Complete(int assignmentID, int reportID, int teamID, string completionNotes)
        {
            int userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);

            try
            {
                DbHelper.ExecuteStoredProcedureNonQuery("sp_CompleteAssignment",
                    new SqlParameter("@AssignmentID", assignmentID),
                    new SqlParameter("@ReportID", reportID),
                    new SqlParameter("@TeamID", teamID),
                    new SqlParameter("@CompletionNotes", completionNotes ?? ""),
                    new SqlParameter("@UserID", userId));

                TempData["Success"] = "Assignment marked as completed.";
            }
            catch (Exception ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction("Index");
        }

        [HttpPost]
        public IActionResult MarkBusy(int assignmentID, int reportID, int teamID)
        {
            int userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);

            try
            {
                DbHelper.ExecuteStoredProcedureNonQuery("sp_MarkTeamBusy",
                    new SqlParameter("@AssignmentID", assignmentID),
                    new SqlParameter("@ReportID", reportID),
                    new SqlParameter("@TeamID", teamID),
                    new SqlParameter("@UserID", userId));

                TempData["Success"] = "Team status updated to Busy (deployed).";
            }
            catch (Exception ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction("Index");
        }

        public IActionResult History()
        {
            ViewBag.History = DbHelper.ExecuteQuery(
                @"SELECT ra.AssignmentID, ra.AssignedAt, ra.CompletedAt, ra.Status, ra.CompletionNotes,
                rt.TeamName, tt.TeamType, er.Location, er.SeverityLevel
                FROM RescueAssignments ra
                INNER JOIN RescueTeams rt ON ra.TeamID = rt.TeamID
                INNER JOIN TeamTypes tt ON rt.TeamTypeID = tt.TeamTypeID
                INNER JOIN EmergencyReports er ON ra.ReportID = er.ReportID
                ORDER BY ra.AssignedAt DESC");

            return View();
        }
    }
}
