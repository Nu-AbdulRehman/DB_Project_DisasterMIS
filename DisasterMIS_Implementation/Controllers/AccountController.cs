using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.Data.SqlClient;
using System.Security.Claims;
using DisasterMIS.Data;

namespace DisasterMIS.Controllers
{
    public class AccountController : Controller
    {
        public IActionResult Login()
        {
            if (User.Identity.IsAuthenticated)
                return RedirectToAction("Index", "Dashboard");
            return View();
        }

        [HttpPost]
        public async Task<IActionResult> Login(string email, string password)
        {
            string passwordHash = "hashed_" + password;

            var dt = DbHelper.ExecuteStoredProcedure("sp_AuthenticateUser",
                new SqlParameter("@Email", email),
                new SqlParameter("@PasswordHash", passwordHash));

            if (dt.Rows.Count == 0)
            {
                ViewBag.Error = "Invalid email or password.";
                return View();
            }

            var row = dt.Rows[0];
            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, row["UserID"].ToString()),
                new Claim(ClaimTypes.Name, row["FullName"].ToString()),
                new Claim(ClaimTypes.Email, row["Email"].ToString()),
                new Claim(ClaimTypes.Role, row["UserType"].ToString()),
                new Claim("UserTypeID", row["UserTypeID"].ToString())
            };

            var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
            var principal = new ClaimsPrincipal(identity);

            await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, principal);

            return RedirectToAction("Index", "Dashboard");
        }

        public async Task<IActionResult> Logout()
        {
            await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
            return RedirectToAction("Login");
        }
    }
}
