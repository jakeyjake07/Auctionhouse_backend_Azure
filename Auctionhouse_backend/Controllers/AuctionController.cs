using Auctionhouse_backend.Core.Interfaces;
using Auctionhouse_backend.DTOs.Auction;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Auctionhouse_backend.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuctionController : ControllerBase
    {

        private readonly IAuctionService _auctionService;
        private readonly IBidService _bidService;

        public AuctionController(IAuctionService auctionService, IBidService bidService)
        {
            _auctionService = auctionService;
            _bidService = bidService;
        }


        [HttpGet]
        public async Task<IActionResult> GetOpenAuctions()
        {
            var auctions = await _auctionService.GetOpenAuctions();
            return Ok(auctions);
        }

        [HttpGet("search")]
        public async Task<IActionResult> Search([FromQuery] string title)
        {
            var auctions = await _auctionService.SearchAuctions(title);
            return Ok(auctions);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetAuctionById(int id)
        {
            var auction = await _auctionService.GetAuctionById(id);
            if (auction == null)
            {
                return NotFound();
            }

            if (auction.IsOpen)
            {

                var bids = await _bidService.GetBidsForAuction(id);
                return Ok(new { auction, bids });
            }
            else
            {

                var winningBid = await _bidService.GetHighestBidForAuction(id);
                return Ok(new { auction, winningBid });
            }
        }


        [HttpPost]
        [Authorize]
        public async Task<IActionResult> CreateAuction(CreateAuctionDto dto)
        {
            var userId = int.Parse(User.FindFirst("id")?.Value ?? "0");

            var auction = await _auctionService.CreateAuction(userId, dto);
            if (auction == null)
                return BadRequest("Could not create auction");

            return Ok(auction);
        }

        [HttpPut("{id}")]
        [Authorize]
        public async Task<IActionResult> UpdateAuction(int id, UpdateAuctionDto dto)
        {
            var userId = int.Parse(User.FindFirst("id")?.Value ?? "0");

            var auction = await _auctionService.UpdateAuction(id, userId, dto);
            if (auction == null)
                return Unauthorized("You can only update your own auctions");

            return Ok(auction);
        }

        [HttpDelete("{id}")]
        [Authorize]
        public async Task<IActionResult> DeleteAuction(int id)
        {
            var userId = int.Parse(User.FindFirst("id")?.Value ?? "0");

            var result = await _auctionService.DeleteAuction(id, userId);
            if (!result)
                return Unauthorized("You can only delete your own auctions");

            return NoContent();
        }

        [HttpGet("user/{userId}")]
        [Authorize]
        public async Task<IActionResult> GetUserAuctions(int userId)
        {
            var currentUserId = int.Parse(User.FindFirst("id")?.Value ?? "0");
            if (currentUserId != userId)
                return Unauthorized("You can only view your own account");

            var auctions = await _auctionService.GetUserAuctions(userId);
            return Ok(auctions);
        }

        [HttpGet("search-all")]
        public async Task<IActionResult> SearchAllAuctions([FromQuery] string title, [FromQuery] bool includeClosed)
        {
            var auctions = await _auctionService.SearchAllAuctions(title, includeClosed);
            return Ok(auctions);
        }

    }

}
