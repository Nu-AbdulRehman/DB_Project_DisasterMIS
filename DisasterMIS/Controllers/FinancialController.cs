using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Data.SqlClient;
using System.Security.Claims;
using DisasterMIS.Data;

namespace DisasterMIS.Controllers
{
    [Authorize]
    public class FinancialController : Controller
    {
        public IActionResult Index(string category = "", string dateFrom = "", string dateTo = "")
        {
            string query = "SELECT * FROM vw_FinancialSummary WHERE 1=1";

            var parameters = new List<SqlParameter>();

            if (!string.IsNullOrEmpty(category))
            {
                query += " AND Category = @Category";
                parameters.Add(new SqlParameter("@Category", category));
            }
            if (!string.IsNullOrEmpty(dateFrom))
            {
                query += " AND TransactionDate >= @DateFrom";
                parameters.Add(new SqlParameter("@DateFrom", dateFrom));
            }
            if (!string.IsNullOrEmpty(dateTo))
            {
                query += " AND TransactionDate <= @DateTo";
                parameters.Add(new SqlParameter("@DateTo", dateTo));
            }

            query += " ORDER BY TransactionDate DESC";

            ViewBag.Records = DbHelper.ExecuteQuery(query, parameters.ToArray());
            ViewBag.DisasterEvents = DbHelper.ExecuteQuery("SELECT * FROM DisasterEvents");
            ViewBag.TotalDonations = DbHelper.ExecuteScalar("SELECT ISNULL(SUM(Amount),0) FROM FinancialRecords WHERE Category = 'Donation'");
            ViewBag.TotalExpenses = DbHelper.ExecuteScalar("SELECT ISNULL(SUM(Amount),0) FROM FinancialRecords WHERE Category IN ('Expense','Procurement')");
            ViewBag.CategoryFilter = category;
            ViewBag.DateFrom = dateFrom;
            ViewBag.DateTo = dateTo;
            return View();
        }

        [Authorize(Roles = "Administrator,Finance Officer")]
        public IActionResult Create()
        {
            ViewBag.DisasterEvents = DbHelper.ExecuteQuery("SELECT * FROM DisasterEvents");
            return View();
        }

        [HttpPost]
        [Authorize(Roles = "Administrator,Finance Officer")]
        public IActionResult Create(decimal amount, string category, string description, int eventID)
        {
            int userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);

            DbHelper.ExecuteStoredProcedureNonQuery("sp_RecordFinancialTransaction",
                new SqlParameter("@Amount", amount),
                new SqlParameter("@Category", category),
                new SqlParameter("@Description", description ?? (object)DBNull.Value),
                new SqlParameter("@EventID", eventID),
                new SqlParameter("@UserID", userId));

            TempData["Success"] = "Transaction recorded successfully.";
            return RedirectToAction("Index");
        }

        [Authorize(Roles = "Administrator,Finance Officer")]
        public IActionResult Delete(int id)
        {
            int userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);

            DbHelper.ExecuteStoredProcedureNonQuery("sp_DeleteFinancialRecord",
                new SqlParameter("@TransactionID", id),
                new SqlParameter("@UserID", userId));

            return RedirectToAction("Index");
        }

        public IActionResult Summary()
        {
            ViewBag.ByCategoryData = DbHelper.ExecuteQuery(
                "SELECT Category, SUM(Amount) AS Total, COUNT(*) AS Transactions FROM FinancialRecords GROUP BY Category");

            ViewBag.ByEventData = DbHelper.ExecuteQuery(
                @"SELECT de.DisasterType, fr.Category, SUM(fr.Amount) AS Total
                FROM FinancialRecords fr
                INNER JOIN DisasterEvents de ON fr.EventID = de.EventID
                GROUP BY de.DisasterType, fr.Category
                ORDER BY de.DisasterType");

            ViewBag.MonthlyData = DbHelper.ExecuteQuery(
                @"SELECT FORMAT(TransactionDate, 'yyyy-MM') AS Month, Category, SUM(Amount) AS Total
                FROM FinancialRecords
                GROUP BY FORMAT(TransactionDate, 'yyyy-MM'), Category
                ORDER BY Month DESC");

            return View();
        }
    }
}
