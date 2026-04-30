using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Data.SqlClient;
using DisasterMIS.Data;

namespace DisasterMIS.Controllers
{
    [Authorize(Roles = "Administrator")]
    public class AuditController : Controller
    {
        public IActionResult Index(string table = "", string action = "", string dateFrom = "", string dateTo = "")
        {
            string query = @"SELECT al.LogID, al.UserID, al.Action, al.OldValue, al.NewValue, al.Timestamp,
                u.FullName AS UserName, t.AffectedTable
                FROM AuditLog al
                INNER JOIN Users u ON al.UserID = u.UserID
                INNER JOIN Tables t ON al.TableID = t.TableID
                WHERE 1=1";

            var parameters = new List<SqlParameter>();

            if (!string.IsNullOrEmpty(table))
            {
                query += " AND t.AffectedTable = @Table";
                parameters.Add(new SqlParameter("@Table", table));
            }
            if (!string.IsNullOrEmpty(action))
            {
                query += " AND al.Action = @Action";
                parameters.Add(new SqlParameter("@Action", action));
            }
            if (!string.IsNullOrEmpty(dateFrom))
            {
                query += " AND al.Timestamp >= @DateFrom";
                parameters.Add(new SqlParameter("@DateFrom", dateFrom));
            }
            if (!string.IsNullOrEmpty(dateTo))
            {
                query += " AND al.Timestamp <= @DateTo";
                parameters.Add(new SqlParameter("@DateTo", dateTo));
            }

            query += " ORDER BY al.Timestamp DESC";

            ViewBag.Logs = DbHelper.ExecuteQuery(query, parameters.ToArray());
            ViewBag.Tables = DbHelper.ExecuteQuery("SELECT DISTINCT AffectedTable FROM Tables ORDER BY AffectedTable");
            ViewBag.TableFilter = table;
            ViewBag.ActionFilter = action;
            return View();
        }

        public IActionResult UserActivity(int userID)
        {
            ViewBag.UserInfo = DbHelper.ExecuteQuery(
                "SELECT u.FullName, u.Email, ut.UserType FROM Users u INNER JOIN UserTypes ut ON u.UserTypeID = ut.UserTypeID WHERE u.UserID = @UserID",
                new SqlParameter("@UserID", userID));

            ViewBag.Activity = DbHelper.ExecuteQuery(
                @"SELECT al.LogID, al.Action, t.AffectedTable, al.Timestamp, al.NewValue
                FROM AuditLog al
                INNER JOIN Tables t ON al.TableID = t.TableID
                WHERE al.UserID = @UserID
                ORDER BY al.Timestamp DESC",
                new SqlParameter("@UserID", userID));

            ViewBag.UserID = userID;
            return View();
        }
    }
}
