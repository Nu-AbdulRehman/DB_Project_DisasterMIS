using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Data.SqlClient;
using System.Security.Claims;
using DisasterMIS.Data;

namespace DisasterMIS.Controllers
{
    [Authorize]
    public class ResourceController : Controller
    {
        public IActionResult Index()
        {
            ViewBag.Resources = DbHelper.ExecuteQuery(
                @"SELECT r.ResourceID, r.ResourceName, r.StockLevel, r.ThresholdLevel,
                rtype.ResourceType,
                CASE WHEN r.StockLevel <= r.ThresholdLevel THEN 'Low Stock' ELSE 'OK' END AS StockStatus
                FROM Resources r
                INNER JOIN ResourceTypes rtype ON r.ResourceTypeID = rtype.ResourceTypeID
                ORDER BY rtype.ResourceType, r.ResourceName");

            return View();
        }

        public IActionResult Warehouses()
        {
            ViewBag.Stock = DbHelper.ExecuteQuery(
                @"SELECT w.Name AS WarehouseName, w.Location, r.ResourceName, ws.Stock,
                rtype.ResourceType
                FROM WarehouseStock ws
                INNER JOIN Warehouses w ON ws.WarehouseID = w.WarehouseID
                INNER JOIN Resources r ON ws.ResourceID = r.ResourceID
                INNER JOIN ResourceTypes rtype ON r.ResourceTypeID = rtype.ResourceTypeID
                ORDER BY w.Name, rtype.ResourceType");

            ViewBag.Warehouses = DbHelper.ExecuteQuery("SELECT * FROM Warehouses");
            return View();
        }

        public IActionResult Allocate()
        {
            ViewBag.Resources = DbHelper.ExecuteQuery(
                @"SELECT r.ResourceID, r.ResourceName, r.StockLevel, rtype.ResourceType
                FROM Resources r
                INNER JOIN ResourceTypes rtype ON r.ResourceTypeID = rtype.ResourceTypeID
                WHERE r.StockLevel > 0");

            ViewBag.Reports = DbHelper.ExecuteQuery(
                @"SELECT er.ReportID, er.Location, er.SeverityLevel, de.DisasterType
                FROM EmergencyReports er
                INNER JOIN DisasterEvents de ON er.EventID = de.EventID
                WHERE er.Status IN ('Pending','Active')
                ORDER BY er.SeverityLevel DESC");

            return View();
        }

        [HttpPost]
        public IActionResult Allocate(int resourceID, int reportID, int quantity)
        {
            int userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);

            try
            {
                DbHelper.ExecuteStoredProcedureNonQuery("sp_AllocateResource",
                    new SqlParameter("@ResourceID", resourceID),
                    new SqlParameter("@ReportID", reportID),
                    new SqlParameter("@Quantity", quantity),
                    new SqlParameter("@UserID", userId));

                TempData["Success"] = "Resource allocated successfully.";
            }
            catch (Exception ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction("Index");
        }

        public IActionResult Allocations()
        {
            ViewBag.Allocations = DbHelper.ExecuteQuery(
                @"SELECT ra.AllocationID, ra.ResourceID, ra.ReportID, ra.Quantity, ra.Status, ra.AllocationDate,
                r.ResourceName, rtype.ResourceType,
                er.Location, er.SeverityLevel
                FROM ResourceAllocations ra
                INNER JOIN Resources r ON ra.ResourceID = r.ResourceID
                INNER JOIN ResourceTypes rtype ON r.ResourceTypeID = rtype.ResourceTypeID
                INNER JOIN EmergencyReports er ON ra.ReportID = er.ReportID
                ORDER BY ra.AllocationDate DESC");

            return View();
        }

        [Authorize(Roles = "Administrator,Warehouse Manager")]
        public IActionResult AddResource()
        {
            ViewBag.ResourceTypes = DbHelper.ExecuteQuery("SELECT * FROM ResourceTypes");
            return View();
        }

        [HttpPost]
        [Authorize(Roles = "Administrator,Warehouse Manager")]
        public IActionResult AddResource(string resourceName, int stockLevel, int thresholdLevel, int resourceTypeID)
        {
            int userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);

            DbHelper.ExecuteStoredProcedureNonQuery("sp_AddResource",
                new SqlParameter("@ResourceName", resourceName),
                new SqlParameter("@StockLevel", stockLevel),
                new SqlParameter("@ThresholdLevel", thresholdLevel),
                new SqlParameter("@ResourceTypeID", resourceTypeID),
                new SqlParameter("@UserID", userId));

            return RedirectToAction("Index");
        }

        [HttpPost]
        [Authorize(Roles = "Administrator,Warehouse Manager")]
        public IActionResult UpdateStock(int resourceID, int additionalStock)
        {
            int userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);

            DbHelper.ExecuteStoredProcedureNonQuery("sp_UpdateResourceStock",
                new SqlParameter("@ResourceID", resourceID),
                new SqlParameter("@AdditionalStock", additionalStock),
                new SqlParameter("@UserID", userId));

            TempData["Success"] = "Stock updated successfully.";
            return RedirectToAction("Index");
        }

        [HttpPost]
        [Authorize(Roles = "Administrator,Warehouse Manager,Field Officer")]
        public IActionResult ConsumeResource(int allocationID, int resourceID, int reportID)
        {
            int userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);

            DbHelper.ExecuteStoredProcedureNonQuery("sp_ConsumeResource",
                new SqlParameter("@AllocationID", allocationID),
                new SqlParameter("@ResourceID", resourceID),
                new SqlParameter("@ReportID", reportID),
                new SqlParameter("@UserID", userId));

            TempData["Success"] = "Resource marked as consumed.";
            return RedirectToAction("Allocations");
        }
    }
}
