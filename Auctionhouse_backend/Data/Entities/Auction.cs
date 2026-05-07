using System.ComponentModel.DataAnnotations;

namespace Auctionhouse_backend.Data.Entities
{
    public class Auction
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(100)]
        public string Title { get; set; } = string.Empty;

        [Required]
        public string Description { get; set; } = string.Empty;

        [Required]
        public decimal StartingPrice { get; set; }

        [Required]
        public DateTime StartDate { get; set; }

        [Required]
        public DateTime EndDate { get; set; }

        [Required]
        public int UserId { get; set; }

        public bool IsActive { get; set; } = true;

        public User? User { get; set; }
        public ICollection<Bid>? Bids { get; set; }

    }
}
