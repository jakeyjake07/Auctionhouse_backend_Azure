using Auctionhouse_backend.Core.Interfaces;
using Auctionhouse_backend.DTOs.Bid;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Auctionhouse_backend.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class BidController : ControllerBase
    {
        private readonly IBidService _bidService;

        public BidController(IBidService bidService)
        {
            _bidService = bidService;
        }

        [HttpPost]
        [Authorize]
        public async Task<IActionResult> PlaceBid(PlaceBidDto dto)
        {
            var userId = int.Parse(User.FindFirst("id")?.Value ?? "0");

            var bid = await _bidService.PlaceBid(userId, dto);
            if (bid == null)
                return BadRequest("Cannot place bid");

            return Ok(bid);
        }

        [HttpGet("auction/{auctionId}")]
        public async Task<IActionResult> GetBidsForAuction(int auctionId)
        {
            var bids = await _bidService.GetBidsForAuction(auctionId);
            return Ok(bids);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetBidById(int id)
        {
            var bid = await _bidService.GetBidById(id);
            if (bid == null)
                return NotFound();
            return Ok(bid);
        }

        [HttpDelete("{id}")]
        [Authorize]
        public async Task<IActionResult> RetractBid(int id)
        {
            var userId = int.Parse(User.FindFirst("id")?.Value ?? "0");

            var result = await _bidService.DeleteBid(id, userId);
            if (!result)
                return BadRequest("Cannot retract bid");

            return NoContent();
        }
    }
}
