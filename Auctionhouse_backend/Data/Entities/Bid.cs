using System.ComponentModel.DataAnnotations;

namespace Auctionhouse_backend.Data.Entities
{
    public class Bid
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public decimal Amount { get; set; }

        [Required]
        public DateTime BidDate { get; set; }

        [Required]
        public int UserId { get; set; }

        [Required]
        public int AuctionId { get; set; }

        public User? User { get; set; }
        public Auction? Auction { get; set; }

    }

}
