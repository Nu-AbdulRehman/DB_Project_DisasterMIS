using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Data.SqlClient;
using System.Security.Claims;
using DisasterMIS.Data;

namespace DisasterMIS.Controllers
{
    [Authorize]
    public class HospitalController : Controller
    {
        public IActionResult Index()
        {
            ViewBag.Hospitals = DbHelper.ExecuteQuery(
                @"SELECT h.HospitalID, h.Name, h.Location, h.TotalBeds,
                h.TotalBeds - COUNT(a.PatientID) AS AvailableBeds,
                SUM(CASE WHEN p.Status = 'Critical' THEN 1 ELSE 0 END) AS CriticalCases
                FROM Hospitals h
                LEFT JOIN Admits a ON h.HospitalID = a.HospitalID
                LEFT JOIN Patients p ON a.PatientID = p.PatientID
                GROUP BY h.HospitalID, h.Name, h.Location, h.TotalBeds
                ORDER BY h.Name");

            return View();
        }

        public IActionResult Patients()
        {
            ViewBag.Patients = DbHelper.ExecuteQuery(
                @"SELECT p.PatientID, p.FirstName, p.LastName, p.Status,
                h.HospitalID, h.Name AS HospitalName, a.BedNumber, a.AdmissionDate
                FROM Patients p
                INNER JOIN Admits a ON p.PatientID = a.PatientID
                INNER JOIN Hospitals h ON a.HospitalID = h.HospitalID
                ORDER BY a.AdmissionDate DESC");

            return View();
        }

        public IActionResult Admit()
        {
            ViewBag.Hospitals = DbHelper.ExecuteQuery(
                @"SELECT h.HospitalID, h.Name,
                h.TotalBeds - COUNT(a.PatientID) AS AvailableBeds
                FROM Hospitals h
                LEFT JOIN Admits a ON h.HospitalID = a.HospitalID
                GROUP BY h.HospitalID, h.Name, h.TotalBeds
                HAVING h.TotalBeds - COUNT(a.PatientID) > 0");

            return View();
        }

        [HttpPost]
        public IActionResult Admit(string firstName, string lastName, string status, int hospitalID, int bedNumber)
        {
            int userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);

            try
            {
                DbHelper.ExecuteStoredProcedureNonQuery("sp_AdmitPatient",
                    new SqlParameter("@FirstName", firstName),
                    new SqlParameter("@LastName", lastName),
                    new SqlParameter("@Status", status),
                    new SqlParameter("@HospitalID", hospitalID),
                    new SqlParameter("@BedNumber", bedNumber),
                    new SqlParameter("@UserID", userId));

                TempData["Success"] = "Patient admitted successfully.";
            }
            catch (Exception ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction("Patients");
        }

        [HttpPost]
        public IActionResult UpdatePatientStatus(int patientID, string status)
        {
            int userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);

            DbHelper.ExecuteStoredProcedureNonQuery("sp_UpdatePatientStatus",
                new SqlParameter("@PatientID", patientID),
                new SqlParameter("@Status", status),
                new SqlParameter("@UserID", userId));

            return RedirectToAction("Patients");
        }

        [HttpPost]
        public IActionResult Discharge(int patientID, int hospitalID)
        {
            int userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);

            DbHelper.ExecuteStoredProcedureNonQuery("sp_DischargePatient",
                new SqlParameter("@PatientID", patientID),
                new SqlParameter("@HospitalID", hospitalID),
                new SqlParameter("@UserID", userId));

            return RedirectToAction("Patients");
        }
    }
}
