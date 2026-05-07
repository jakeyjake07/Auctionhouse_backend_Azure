using System.ComponentModel.DataAnnotations;

namespace Auctionhouse_backend.DTOs.Auction
{
    public class CreateAuctionDto
    {
        [Required]
        [MaxLength(200)]
        public string Title { get; set; } = string.Empty;

        [Required]
        public string Description { get; set; } = string.Empty;

        [Required]
        [Range(0.01, double.MaxValue, ErrorMessage = "Starting price must be greater than 0")]
        public decimal StartingPrice { get; set; }

        [Required]
        public DateTime EndDate { get; set; }
    }
}
