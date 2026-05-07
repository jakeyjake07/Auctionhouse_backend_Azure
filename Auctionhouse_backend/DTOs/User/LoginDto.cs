using System.ComponentModel.DataAnnotations;

namespace Auctionhouse_backend.DTOs.User
{
    public class LoginDto
    {
        [Required]
        public string Username { get; set; }

        [Required]
        public string Password { get; set; }
    }
}
