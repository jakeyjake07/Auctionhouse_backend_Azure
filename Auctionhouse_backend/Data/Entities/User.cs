using System.ComponentModel.DataAnnotations;

namespace Auctionhouse_backend.Data.Entities
{
    public class User
    {

        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(50)]
        public string Username { get; set; } = string.Empty;

        [Required]
        public string PasswordHash { get; set; } = string.Empty;

        [Required]
        [EmailAddress]
        [MaxLength(100)]
        public string Email { get; set; } = string.Empty;

        public bool IsActive { get; set; } = true;

        public bool IsAdmin { get; set; } = false;

        public ICollection<Auction> Auctions { get; set; } = new List<Auction>();
        public ICollection<Bid>? Bids { get; set; } = new List<Bid>();

    }
}
