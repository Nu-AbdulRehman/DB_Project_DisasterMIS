using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Data.SqlClient;
using System.Security.Claims;
using DisasterMIS.Data;

namespace DisasterMIS.Controllers
{
    [Authorize]
    public class ApprovalController : Controller
    {
        public IActionResult Index(string status = "Pending")
        {
            int userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);
            string role = User.FindFirst(ClaimTypes.Role)?.Value;

            string query = @"SELECT aw.ApprovalID, aw.RequesterID, aw.Status, aw.Notes,
                rt.RequestType, aw.AllocationID,
                req.FullName AS RequesterName,
                apr.FullName AS ApproverName
                FROM ApprovalWorkflow aw
                INNER JOIN RequestTypes rt ON aw.RequestTypeID = rt.RequestTypeID
                INNER JOIN Users req ON aw.RequesterID = req.UserID
                LEFT JOIN Users apr ON aw.ApproverID = apr.UserID
                WHERE 1=1";

            var parameters = new List<SqlParameter>();

            if (!string.IsNullOrEmpty(status))
            {
                query += " AND aw.Status = @Status";
                parameters.Add(new SqlParameter("@Status", status));
            }

            if (role != "Administrator")
            {
                query += " AND aw.RequesterID = @UserID";
                parameters.Add(new SqlParameter("@UserID", userId));
            }

            query += " ORDER BY aw.ApprovalID DESC";

            ViewBag.Approvals = DbHelper.ExecuteQuery(query, parameters.ToArray());
            ViewBag.RequestTypes = DbHelper.ExecuteQuery("SELECT * FROM RequestTypes");
            ViewBag.StatusFilter = status;
            return View();
        }

        public IActionResult Create()
        {
            ViewBag.RequestTypes = DbHelper.ExecuteQuery("SELECT * FROM RequestTypes");
            ViewBag.PendingAllocations = DbHelper.ExecuteQuery(
                @"SELECT ra.AllocationID, r.ResourceName, ra.Quantity, er.Location
                FROM ResourceAllocations ra
                INNER JOIN Resources r ON ra.ResourceID = r.ResourceID
                INNER JOIN EmergencyReports er ON ra.ReportID = er.ReportID
                WHERE ra.Status = 'Pending'");
            return View();
        }

        [HttpPost]
        public IActionResult Create(int requestTypeID, string notes, int? allocationID)
        {
            int userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);

            DbHelper.ExecuteStoredProcedureNonQuery("sp_SubmitApprovalRequest",
                new SqlParameter("@RequesterID", userId),
                new SqlParameter("@RequestTypeID", requestTypeID),
                new SqlParameter("@AllocationID", (object)allocationID ?? DBNull.Value),
                new SqlParameter("@Notes", notes ?? (object)DBNull.Value));

            TempData["Success"] = "Approval request submitted.";
            return RedirectToAction("Index");
        }

        [HttpPost]
        [Authorize(Roles = "Administrator")]
        public IActionResult Process(int approvalID, int requesterID, string action, string notes)
        {
            int approverId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);
            string status = action == "Approve" ? "Approved" : "Rejected";

            DbHelper.ExecuteStoredProcedureNonQuery("sp_ProcessApproval",
                new SqlParameter("@ApprovalID", approvalID),
                new SqlParameter("@RequesterID", requesterID),
                new SqlParameter("@ApproverID", approverId),
                new SqlParameter("@Status", status),
                new SqlParameter("@Notes", notes ?? (object)DBNull.Value));

            TempData["Success"] = $"Request {status.ToLower()} successfully.";
            return RedirectToAction("Index");
        }
    }
}
