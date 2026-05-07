using Auctionhouse_backend.Core.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Auctionhouse_backend.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class AdminController : ControllerBase
    {
        private readonly IUserService _userService;
        private readonly IAuctionService _auctionService;

        public AdminController(IUserService userService, IAuctionService auctionService)
        {
            _userService = userService;
            _auctionService = auctionService;
        }

        private bool IsAdmin()
        {
            return User.FindFirst("isAdmin")?.Value == "True";
        }


        [HttpGet("users")]
        public async Task<IActionResult> GetAllUsers()
        {
            if (!IsAdmin())
                return Unauthorized("Admin access required");


            var users = await _userService.GetAllUsers();
            return Ok(users);
        }

        [HttpPut("users/{userId}/toggle-active")]
        public async Task<IActionResult> ToggleUserActive(int userId)
        {
            if (!IsAdmin())
                return Unauthorized("Admin access required");


            var adminId = int.Parse(User.FindFirst("id")?.Value ?? "0");

            var result = await _userService.ToggleUserActive(userId, adminId);
            if (!result)
                return NotFound("User not found");

            return Ok();
        }

        [HttpPut("auctions/{auctionId}/toggle-active")]
        public async Task<IActionResult> ToggleAuctionActive(int auctionId)
        {
            if (!IsAdmin())
                return Unauthorized("Admin access required");

            var adminId = int.Parse(User.FindFirst("id")?.Value ?? "0");

            var result = await _auctionService.ToggleAuctionActive(auctionId, adminId);
            if (!result)
                return NotFound("Auction not found");

            return Ok();
        }

        [HttpGet("auctions/all")]
        public async Task<IActionResult> GetAllAuctions([FromQuery] bool includeClosed)
        {
            if (!IsAdmin())
                return Unauthorized("Admin access required");

            var auctions = await _auctionService.GetAllAuctions(includeClosed);
            return Ok(auctions);
        }


        [HttpGet("auctions/search")]
        public async Task<IActionResult> SearchAllAuctions([FromQuery] string title, [FromQuery] bool includeClosed)
        {
            if (!IsAdmin())
                return Unauthorized("Admin access required");

            var auctions = await _auctionService.SearchAllAuctions(title, includeClosed);
            return Ok(auctions);
        }

    }
}

