using System.ComponentModel.DataAnnotations;

namespace Auctionhouse_backend.DTOs.Bid
{
    public class PlaceBidDto
    {
        [Required]
        public int AuctionId { get; set; }

        [Required]
        [Range(0.01, double.MaxValue)]
        public decimal Amount { get; set; }
    }
}
